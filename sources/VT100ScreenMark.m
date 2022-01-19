//
//  VT100ScreenMark.m
//  iTerm
//
//  Created by George Nachman on 12/5/13.
//
//

#import "VT100ScreenMark.h"
#import "CapturedOutput.h"
#import "NSDictionary+iTerm.h"
#import "NSObject+iTerm.h"
#import "NSStringITerm.h"

static NSString *const kScreenMarkIsPrompt = @"Is Prompt";
static NSString *const kMarkGuidKey = @"Guid";
static NSString *const kMarkCapturedOutputKey = @"Captured Output";
static NSString *const kMarkCommandKey = @"Command";
static NSString *const kMarkCodeKey = @"Code";
static NSString *const kMarkHasCode = @"Has Code";
static NSString *const kMarkStartDateKey = @"Start Date";
static NSString *const kMarkEndDateKey = @"End Date";
static NSString *const kMarkSessionGuidKey = @"Session Guid";
static NSString *const kMarkPromptRange = @"Prompt Range";
static NSString *const kMarkCommandRange = @"Command Range";
static NSString *const kMarkOutputStart = @"Output Start";

#warning TODO: I need an immutable protocol for this. In particular, setCommand: calls delegate.markDidBecomeCommandMark(_:) which mutates VT100Screen. So that must only happen on the mutation thread!
@implementation VT100ScreenMark {
    NSMutableArray *_capturedOutput;
}

@synthesize isPrompt = _isPrompt;
@synthesize guid = _guid;
@synthesize clearCount = _clearCount;
@synthesize capturedOutput = _capturedOutput;
@synthesize code = _code;
@synthesize hasCode = _hasCode;
@synthesize command = _command;
@synthesize startDate = _startDate;
@synthesize endDate = _endDate;
@synthesize sessionGuid = _sessionGuid;
@synthesize promptRange = _promptRange;
@synthesize commandRange = _commandRange;
@synthesize outputStart = _outputStart;

+ (NSMapTable *)registry {
    static NSMapTable *registry;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registry = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality)
                                             valueOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                                 capacity:1024];
    });
    return registry;
}

+ (id<VT100ScreenMarkReading>)markWithGuid:(NSString *)guid {
    @synchronized([VT100ScreenMark class]) {
        return [self.registry objectForKey:guid];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        @synchronized([VT100ScreenMark class]) {
            [[self.class registry] setObject:self forKey:self.guid];
        }
        _promptRange = VT100GridAbsCoordRangeMake(-1, -1, -1, -1);
        _commandRange = VT100GridAbsCoordRangeMake(-1, -1, -1, -1);
        _outputStart = VT100GridAbsCoordMake(-1, -1);
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super initWithDictionary:dict];
    if (self) {
        _code = [dict[kMarkCodeKey] intValue];
        _hasCode = [dict[kMarkHasCode] boolValue];
        if (_code && !_hasCode) {
            // Not so great way of migrating old marks. Misses those with a value of 0 :(
            _hasCode = YES;
        }
        _isPrompt = [dict[kScreenMarkIsPrompt] boolValue];
        if ([dict[kMarkGuidKey] isKindOfClass:[NSString class]]) {
            _guid = [dict[kMarkGuidKey] copy];
        } else {
            _guid = [NSString uuid];
        }
        _sessionGuid = [dict[kMarkSessionGuidKey] copy];
        NSTimeInterval start = [dict[kMarkStartDateKey] doubleValue];
        if (start > 0) {
            _startDate = [NSDate dateWithTimeIntervalSinceReferenceDate:start];
        }
        NSTimeInterval end = [dict[kMarkEndDateKey] doubleValue];
        if (end > 0) {
            _endDate = [NSDate dateWithTimeIntervalSinceReferenceDate:end];
        }
        NSMutableArray *array = [NSMutableArray array];
        _capturedOutput = array;
        for (NSDictionary *capturedOutputDict in dict[kMarkCapturedOutputKey]) {
            [array addObject:[CapturedOutput capturedOutputWithDictionary:capturedOutputDict]];
        }
        if ([dict[kMarkCommandKey] isKindOfClass:[NSString class]]) {
            _command = [dict[kMarkCommandKey] copy];
        }
        if (dict[kMarkPromptRange]) {
            _promptRange = [dict[kMarkPromptRange] gridAbsCoordRange];
        } else {
            _promptRange = VT100GridAbsCoordRangeMake(-1, -1, -1, -1);
        }
        if (dict[kMarkCommandRange]) {
            _commandRange = [dict[kMarkCommandRange] gridAbsCoordRange];
        } else {
            _commandRange = VT100GridAbsCoordRangeMake(-1, -1, -1, -1);
        }
        if (dict[kMarkOutputStart]) {
            _outputStart = [dict[kMarkOutputStart] gridAbsCoord];
        } else {
            _outputStart = VT100GridAbsCoordMake(-1, -1);
        }
        @synchronized([VT100ScreenMark class]) {
            [[self.class registry] setObject:self forKey:self.guid];
        }
    }
    return self;
}

- (void)dealloc {
    @synchronized([VT100ScreenMark class]) {
        [[self.class registry] removeObjectForKey:_guid];
    }
}

- (NSString *)guid {
    if (!_guid) {
        self.guid = [NSString uuid];
    }
    return _guid;
}

- (NSArray *)capturedOutputDictionaries {
    NSMutableArray *array = [NSMutableArray array];
    for (CapturedOutput *capturedOutput in _capturedOutput) {
        [array addObject:capturedOutput.dictionaryValue];
    }
    return array;
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *dict = [[super dictionaryValue] mutableCopy];
    dict[kScreenMarkIsPrompt] = @(_isPrompt);
    dict[kMarkGuidKey] = self.guid;
    dict[kMarkCapturedOutputKey] = [self capturedOutputDictionaries];
    dict[kMarkHasCode] = @(_hasCode);
    dict[kMarkCodeKey] = @(_code);
    dict[kMarkCommandKey] = _command ?: [NSNull null];
    dict[kMarkStartDateKey] = @([self.startDate timeIntervalSinceReferenceDate]);
    dict[kMarkEndDateKey] = @([self.endDate timeIntervalSinceReferenceDate]);
    dict[kMarkSessionGuidKey] = self.sessionGuid ?: [NSNull null];
    dict[kMarkPromptRange] = [NSDictionary dictionaryWithGridAbsCoordRange:_promptRange];
    dict[kMarkCommandRange] = [NSDictionary dictionaryWithGridAbsCoordRange:_commandRange];
    dict[kMarkOutputStart] = [NSDictionary dictionaryWithGridAbsCoord:_outputStart];

    return dict;
}

- (void)addCapturedOutput:(CapturedOutput *)capturedOutput {
#warning TODO: This needs to be thread-safe. Or move it all to one thread. But be sure to check it!
    if (!_capturedOutput) {
        _capturedOutput = [[NSMutableArray alloc] init];
    } else if ([self mergeCapturedOutputIfPossible:capturedOutput]) {
        return;
    }
    [_capturedOutput addObject:capturedOutput];
}

- (BOOL)mergeCapturedOutputIfPossible:(CapturedOutput *)capturedOutput {
    CapturedOutput *last = _capturedOutput.lastObject;
    if (![last canMergeFrom:capturedOutput]) {
        return NO;
    }
    [last mergeFrom:capturedOutput];
    return YES;
}

- (void)setCommand:(NSString *)command {
    if (!_command) {
#warning TODO: This will need to be called on the mutation thread
        [self.delegate markDidBecomeCommandMark:self];
    }
    _command = [command copy];
    self.startDate = [NSDate date];
}

- (void)setCode:(int)code {
    _code = code;
    _hasCode = YES;
}

- (void)incrementClearCount {
    _clearCount += 1;
}

- (id<VT100ScreenMarkReading>)doppelganger {
    return (id<VT100ScreenMarkReading>)[super doppelganger];
}

@end

