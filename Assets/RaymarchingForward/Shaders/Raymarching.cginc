#ifndef RAYMARCHING_CGINC
#define RAYMARCHING_CGINC

#include "UnityShaderVariables.cginc"
#include "UnityCG.cginc"

inline float smoothMin(float d1, float d2, float k)
{
    float h = exp(-k * d1) + exp(-k * d2);
    return -log(h) / k;
}

inline float sphere(float3 pos, float radius)
{
    return length(pos) - radius;
}

inline float3 ToLocal(float3 pos)
{
    return mul(unity_WorldToObject, float4(pos, 1.0)).xyz;
}

inline bool IsInnerBox(float3 pos, float3 scale)
{
    return all(max(scale * 0.5 - abs(pos), 0.0));
}

inline float3 GetWorldScale()
{
    return float3(
        length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
        length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
        length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z)));
}

inline float3 GetCameraForward()
{ 
    return -UNITY_MATRIX_V[2].xyz;
}

inline float _DistanceFunction(float3 pos)
{
    return smoothMin(
        sphere(pos - float3(0.2, 0.2, 0.2), 0.28),
        sphere(pos - float3(-0.2, -0.2, -0.2), 0.28),
        8.0);
}

inline float DistanceFunction(float3 pos)
{
    return _DistanceFunction(ToLocal(pos) * GetWorldScale());
}

inline float3 GetNormal(float3 pos)
{
    const float d = 0.001;
    return 0.5 + 0.5 * normalize(float3(
        DistanceFunction(pos + float3(  d, 0.0, 0.0)) - DistanceFunction(pos + float3( -d, 0.0, 0.0)),
        DistanceFunction(pos + float3(0.0,   d, 0.0)) - DistanceFunction(pos + float3(0.0,  -d, 0.0)),
        DistanceFunction(pos + float3(0.0, 0.0,   d)) - DistanceFunction(pos + float3(0.0, 0.0,  -d))));
}

inline float EncodeDepth(float4 pos)
{
    float z = pos.z / pos.w;
#if defined(SHADER_API_GLCORE) || defined(SHADER_API_OPENGL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
    return z * 0.5 + 0.5;
#else 
    return z;
#endif 
}

inline float GetCameraDepth(float3 pos)
{
    float4 vpPos = mul(UNITY_MATRIX_VP, float4(pos, 1.0));
    return EncodeDepth(vpPos);
}

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 projPos : TEXCOORD1;
    float4 worldPos  : TEXCOORD2;
    UNITY_FOG_COORDS(3)
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

v2f vert(appdata v)
{
    v2f o;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(v2f, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o); 
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.uv = v.uv;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.projPos = ComputeNonStereoScreenPos(o.vertex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    UNITY_TRANSFER_FOG(o, o.vertex);

    return o;
}

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
float4 _Color;
int _Loop;
float _MinDist;

inline void raymarch(inout float3 pos, float4 uv)
{
    float3 to = pos - _WorldSpaceCameraPos;
    float len = length(to);
    float3 dir = normalize(to);
    float eyeDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, uv));
    float maxLen = eyeDepth / dot(dir, GetCameraForward());
    float dist = 0.0;

    for (int n = 0; n < _Loop; ++n) 
    {
        dist = DistanceFunction(pos);
        len += dist;
        pos += dir * dist;
        if (dist < _MinDist || len > maxLen) break;
        if (!IsInnerBox(ToLocal(pos), 1.0)) break;
    }

    if (dist > _MinDist || len > maxLen) discard;
}

float4 fragColor(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    float3 pos = i.worldPos; 
    raymarch(pos, UNITY_PROJ_COORD(i.projPos));
    float3 normal = GetNormal(pos);

    float4 color;
    color.rgb = max(dot(normal, _WorldSpaceLightPos0.xyz), 0.0) * _Color.rgb;
    color.a = _Color.a;
    UNITY_APPLY_FOG(i.fogCoord, color);

    return color;
}

void fragColorDepth(v2f i, out float4 color : SV_Target, out float depth : SV_Depth)
{
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    float3 pos = i.worldPos; 
    raymarch(pos, UNITY_PROJ_COORD(i.projPos));
    float3 normal = GetNormal(pos);

    color.rgb = max(dot(normal, _WorldSpaceLightPos0.xyz), 0.0) * _Color.rgb;
    color.a = _Color.a;
    UNITY_APPLY_FOG(i.fogCoord, color);

    depth = GetCameraDepth(pos);
}

#endif
