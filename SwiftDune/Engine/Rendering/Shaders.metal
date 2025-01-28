//
//  Shaders.metal
//  SwiftDune
//
//  Created by Christophe Buguet on 30/06/2024.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Texture sampling uses nearest neighbor to ensure sharp pixels when upscaled,
// in order to get a good looking VGA game
fragment float4 fragment_main(VertexOut in [[stage_in]], texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    return texture.sample(s, in.texCoord);
}
