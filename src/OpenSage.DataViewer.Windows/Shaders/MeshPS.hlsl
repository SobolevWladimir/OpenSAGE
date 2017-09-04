#include "Mesh.hlsli"

struct LightingConstants
{
    float3 CameraPosition;
    float3 AmbientLightColor;
    float3 Light0Direction;
    float3 Light0Color;
};

ConstantBuffer<LightingConstants> LightingCB : register(b0);

struct PerDrawConstants
{
    uint PrimitiveOffset;
    uint NumTextureStages;
    bool AlphaTest;
    bool Texturing;
};

ConstantBuffer<PerDrawConstants> PerDrawCB : register(b1);

struct VertexMaterial
{
    float3 Ambient;
    float3 Diffuse;
    float3 Specular;
    float Shininess;
    float3 Emissive;
    float Opacity;
};

StructuredBuffer<VertexMaterial> Materials : register(t0);

Buffer<uint> TextureIndices : register(t1);
Texture2D<float4> Textures[] : register(t2);

SamplerState Sampler : register(s0);

float4 main(PSInput input) : SV_TARGET
{
    VertexMaterial material = Materials[input.MaterialIndex];

    float3 lightDir = LightingCB.Light0Direction;

    float3 diffuse = saturate(dot(input.Normal, -lightDir)) * material.Diffuse;

    float3 v = normalize(LightingCB.CameraPosition - input.WorldPosition);
    float3 h = normalize(v - lightDir);
    float specular = saturate(dot(input.Normal, h)) * material.Shininess * material.Specular;

    float4 diffuseTextureColor;
    if (PerDrawCB.Texturing) // TODO: Add optional second texture stage, depending on PerDrawCB.NumTextureStages
    {
        uint textureIndex = TextureIndices[PerDrawCB.PrimitiveOffset + input.PrimitiveID];
        Texture2D<float4> diffuseTexture = Textures[NonUniformResourceIndex(textureIndex)];
        diffuseTextureColor = diffuseTexture.Sample(Sampler, float2(input.UV.x, 1 - input.UV.y));

        if (PerDrawCB.AlphaTest)
        {
            const float alphaTestThreshold = 0x60 / (float) 0xFF;
            if (diffuseTextureColor.a < alphaTestThreshold)
            {
                discard;
            }
        }
    }
    else
    {
        diffuseTextureColor = float4(1, 1, 1, 1);
    }

    float3 ambient = LightingCB.AmbientLightColor * material.Ambient;

    float3 color = (saturate(ambient + diffuse) * diffuseTextureColor.rgb + specular) * LightingCB.Light0Color
        + material.Emissive;

    float alpha = material.Opacity * diffuseTextureColor.a;

    return float4(color, alpha);
}