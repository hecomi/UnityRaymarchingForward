﻿Shader "Raymarching/Forward/AlphaTest"
{

Properties
{
    _Color ("Color", Color) = (0.5, 0.5, 0.5, 1.0)
    _Loop ("Loop", Range(1, 100)) = 30
    _MinDist ("Minimum Distance", Range(0.001, 0.1)) = 0.01
}

SubShader
{

Tags 
{ 
    "Queue" = "AlphaTest" 
    "RenderType" = "Opaque"
    "IgnoreProjector" = "True"
    "DisableBatching" = "True"
}

Pass
{
    Tags { "LightMode" = "ForwardBase" }
    ZWrite On
    //Blend SrcAlpha OneMinusSrcAlpha
    CGPROGRAM
    #include "Raymarching.cginc"
    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile_fog
    #pragma multi_compile_instancing
    ENDCG
}

}

}
