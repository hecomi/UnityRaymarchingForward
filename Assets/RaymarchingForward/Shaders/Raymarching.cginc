#ifndef RAYMARCHING_CGINC
#define RAYMARCHING_CGINC

#include "UnityCG.cginc"

inline float smoothMin(float d1, float d2, float k)
{
    float h = exp(-k * d1) + exp(-k * d2);
    return -log(h) / k;
}

inline float3 mod(float3 a, float3 b)
{
    return frac(abs(a / b)) * abs(b);
}

inline float3 repeat(float3 pos, float3 span)
{
    return mod(pos, span) - span * 0.5;
}

inline float sphere(float3 pos, float radius)
{
    return length(pos) - radius;
}

inline float3 ToLocal(float3 pos)
{
    return mul(unity_WorldToObject, float4(pos, 1.0)).xyz;
}

inline float _DistanceFunction(float3 pos)
{
    return smoothMin(
        sphere(pos - float3(0.2, 0.2, 0.2), 0.3),
        sphere(pos - float3(-0.2, -0.2, -0.2), 0.3),
        8.0);
}

inline float DistanceFunction(float3 pos)
{
    return _DistanceFunction(ToLocal(pos));
}

inline float3 GetCameraPosition()    { return _WorldSpaceCameraPos;      }
inline float3 GetCameraForward()     { return -UNITY_MATRIX_V[2].xyz;    }
inline float3 GetCameraUp()          { return UNITY_MATRIX_V[1].xyz;     }
inline float3 GetCameraRight()       { return UNITY_MATRIX_V[0].xyz;     }
inline float  GetCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }

inline float3 GetNormal(float3 pos)
{
    const float d = 0.001;
    return 0.5 + 0.5 * normalize(float3(
        DistanceFunction(pos + float3(  d, 0.0, 0.0)) - DistanceFunction(pos + float3( -d, 0.0, 0.0)),
        DistanceFunction(pos + float3(0.0,   d, 0.0)) - DistanceFunction(pos + float3(0.0,  -d, 0.0)),
        DistanceFunction(pos + float3(0.0, 0.0,   d)) - DistanceFunction(pos + float3(0.0, 0.0,  -d))));
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
};

v2f vert(appdata v)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o); 
    o.uv = v.uv;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.projPos = ComputeScreenPos(o.vertex);
    COMPUTE_EYEDEPTH(o.projPos.z);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    UNITY_TRANSFER_FOG(o, o.vertex);
    return o;
}

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
fixed4 _Color;
int _Loop;
float _MinDist;

fixed4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);

    float3 xAxis = GetCameraRight();
    float3 yAxis = GetCameraUp();
    float3 zAxis = GetCameraForward();

    float2 screenPos = 2 * (i.projPos.xy / i.projPos.w - 0.5);
    screenPos.x *= _ScreenParams.x / _ScreenParams.y;

    float3 rayDir = normalize(
        (xAxis * screenPos.x) + 
        (yAxis * screenPos.y) + 
        (zAxis * GetCameraFocalLength()));

    float3 pos = i.worldPos;
    float len = length(pos - GetCameraPosition());
    float dist = 0.0;

    float depth = LinearEyeDepth(
        SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
    float maxLen = depth / dot(rayDir, GetCameraForward());

    for (int i = 0; i < _Loop; ++i) 
    {
        dist = DistanceFunction(pos);
        len += dist;
        pos += rayDir * dist;
        if (dist < _MinDist || len > maxLen) break;
    }

    if (dist > _MinDist || len > maxLen) discard;

    float3 normal = GetNormal(pos);
    float3 lightDir = _WorldSpaceLightPos0.xyz;

    fixed4 col;
    col.rgb = max(dot(normal, lightDir), 0.0) * _Color.rgb;
    col.a = _Color.a;
    UNITY_APPLY_FOG(i.fogCoord, col);

    return col;
}

#endif
