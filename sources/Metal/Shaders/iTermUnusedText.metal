//
//  iTermUnusedText.metal
//  iTerm2
//
//  Created by George Nachman on 7/2/18.
//

#include "iTermTextShaderCommon.h"

// The "SolidBackground" functions are used when there is no intermediate pass and we know text will always be
// rendered over a solid background color. This is faster because the shader is quite simple. It
// uses 256 bytes of buffer for each combination of foreground/background color component.
//
// Because of pretty ascii overlap, it is not used currently. It could be used for the first
// pass though, and I don't want this code to get stale, so I'm keeping it around for now.

fragment float4
iTermTextFragmentShaderSolidBackgroundEmoji(iTermTextVertexFunctionOutputEmoji in [[stage_in]],
                                            texture2d<float> texture [[ texture(iTermTextureIndexPrimary) ]],
                                            constant unsigned char *exactColorModels [[ buffer(iTermFragmentBufferIndexColorModels) ]],
                                            constant iTermTextureDimensions *dimensions  [[ buffer(iTermFragmentInputIndexTextureDimensions) ]],
                                            texture2d<float> colorModelsTexture [[ texture(iTermTextureIndexSubpixelModels) ]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    return texture.sample(textureSampler, in.textureCoordinate);
}

fragment float4
iTermTextFragmentShaderSolidBackground(iTermTextVertexFunctionOutput in [[stage_in]],
                                       texture2d<float> texture [[ texture(iTermTextureIndexPrimary) ]],
                                       constant unsigned char *exactColorModels [[ buffer(iTermFragmentBufferIndexColorModels) ]],
                                       constant iTermTextureDimensions *dimensions  [[ buffer(iTermFragmentInputIndexTextureDimensions) ]],
                                       texture2d<float> colorModelsTexture [[ texture(iTermTextureIndexSubpixelModels) ]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    float4 bwColor = texture.sample(textureSampler, in.textureCoordinate);

    if (bwColor.x == 1 && bwColor.y == 1 && bwColor.z == 1) {
        discard_fragment();
    }

    // Not emoji, not underlined

    const short4 bwIntIndices = static_cast<short4>(bwColor * 255);
    // Base index for this color model
    const int3 i = in.colorModelIndex * 256;
    // Find RGB values to map colors in the black-on-white glyph to
    const uchar4 rgba = uchar4(exactColorModels[i.x + bwIntIndices.x],
                               exactColorModels[i.y + bwIntIndices.y],
                               exactColorModels[i.z + bwIntIndices.z],
                               255);
    return static_cast<float4>(rgba) / 255;
}

fragment float4
iTermTextFragmentShaderSolidBackgroundUnderlinedEmoji(iTermTextVertexFunctionOutput in [[stage_in]],
                                                      texture2d<float> texture [[ texture(iTermTextureIndexPrimary) ]],
                                                      constant unsigned char *exactColorModels [[ buffer(iTermFragmentBufferIndexColorModels) ]],
                                                      constant iTermTextureDimensions *dimensions  [[ buffer(iTermFragmentInputIndexTextureDimensions) ]],
                                                      texture2d<float> colorModelsTexture [[ texture(iTermTextureIndexSubpixelModels) ]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    float4 bwColor = texture.sample(textureSampler, in.textureCoordinate);

    float strikethroughWeight = 0;
    if (in.underlineStyle & iTermMetalGlyphAttributesUnderlineStrikethroughFlag) {
        strikethroughWeight = ComputeWeightOfUnderlineRegular(iTermMetalGlyphAttributesUnderlineStrikethrough,
                                                              in.clipSpacePosition.xy,
                                                              in.viewportSize,
                                                              in.cellOffset,
                                                              dimensions->strikethroughOffset,
                                                              dimensions->strikethroughThickness,
                                                              dimensions->textureSize,
                                                              in.textureOffset,
                                                              in.textureCoordinate,
                                                              dimensions->glyphSize,
                                                              dimensions->cellSize,
                                                              texture,
                                                              textureSampler,
                                                              dimensions->scale,
                                                              (in.flags & iTermTextVertexInfoFlagsSolidUnderlines) != 0);
    }
    // Emoji, underlined
    float underlineWeight = ComputeWeightOfUnderlineRegular((in.underlineStyle & iTermMetalGlyphAttributesUnderlineBitmask),
                                                            in.clipSpacePosition.xy,
                                                            in.viewportSize,
                                                            in.cellOffset,
                                                            dimensions->underlineOffset,
                                                            dimensions->underlineThickness,
                                                            dimensions->textureSize,
                                                            in.textureOffset,
                                                            in.textureCoordinate,
                                                            dimensions->glyphSize,
                                                            dimensions->cellSize,
                                                            texture,
                                                            textureSampler,
                                                            dimensions->scale,
                                                            (in.flags & iTermTextVertexInfoFlagsSolidUnderlines) != 0);
    return mix(bwColor,
               in.underlineColor,
               max(strikethroughWeight, underlineWeight));
}

fragment float4
iTermTextFragmentShaderSolidBackgroundUnderlined(iTermTextVertexFunctionOutput in [[stage_in]],
                                                 texture2d<float> texture [[ texture(iTermTextureIndexPrimary) ]],
                                                 constant unsigned char *exactColorModels [[ buffer(iTermFragmentBufferIndexColorModels) ]],
                                                 constant iTermTextureDimensions *dimensions  [[ buffer(iTermFragmentInputIndexTextureDimensions) ]],
                                                 texture2d<float> colorModelsTexture [[ texture(iTermTextureIndexSubpixelModels) ]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    float4 bwColor = texture.sample(textureSampler, in.textureCoordinate);
    float underlineWeight = 0;

    // Not emoji, underlined
    underlineWeight = ComputeWeightOfUnderlineInverted(in.underlineStyle,
                                                       in.clipSpacePosition.xy,
                                                       in.viewportSize,
                                                       in.cellOffset,
                                                       dimensions->underlineOffset,
                                                       dimensions->underlineThickness,
                                                       dimensions->strikethroughOffset,
                                                       dimensions->strikethroughThickness,
                                                       dimensions->textureSize,
                                                       in.textureOffset,
                                                       in.textureCoordinate,
                                                       dimensions->glyphSize,
                                                       dimensions->cellSize,
                                                       texture,
                                                       textureSampler,
                                                       dimensions->scale,
                                                       (in.flags & iTermTextVertexInfoFlagsSolidUnderlines) != 0);
    if (underlineWeight == 0 && bwColor.x == 1 && bwColor.y == 1 && bwColor.z == 1) {
        discard_fragment();
    }

    const short4 bwIntIndices = static_cast<short4>(bwColor * 255);
    // Base index for this color model
    const int3 i = in.colorModelIndex * 256;
    // Find RGB values to map colors in the black-on-white glyph to
    const uchar4 rgba = uchar4(exactColorModels[i.x + bwIntIndices.x],
                               exactColorModels[i.y + bwIntIndices.y],
                               exactColorModels[i.z + bwIntIndices.z],
                               255);
    float4 textColor = static_cast<float4>(rgba) / 255;

    return mix(textColor, in.underlineColor, underlineWeight);
}


