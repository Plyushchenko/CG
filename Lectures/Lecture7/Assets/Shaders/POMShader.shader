//https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://habr.com/ru/post/416163/
Shader "0_Custom/POMShader"
{
    Properties {
        _MainTex("Albedo", 2D) = "white" {}
        _HeightMap("Height Map", 2D) = "white" {}
        _HeightMapScale("Height Map Scale", Range(0, 0.2)) = 0.075

        // normal map texture on the material,
        // default to dummy "flat surface" normalmap
        _NormalMap("Normal Map", 2D) = "bump" {}
        
    }
    SubShader
    {
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct v2f {
                float3 worldPos : TEXCOORD0;
                // these three vectors will hold a 3x3 rotation matrix
                // that transforms from tangent to world space
                half3 tspace0 : TEXCOORD1; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD2; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD3; // tangent.z, bitangent.z, normal.z
                // texture coordinate for the normal map
                float2 uv : TEXCOORD4;
                float4 pos : SV_POSITION;
            };

            // vertex shader now also needs a per-vertex tangent vector.
            // in Unity tangents are 4D vectors, with the .w component used to
            // indicate direction of the bitangent vector.
            // we also need the texture coordinate.
            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(vertex);
                o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
                half3 wNormal = UnityObjectToWorldNormal(normal);
                half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                o.uv = uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _HeightMap;
            float _HeightMapScale;
            
            // normal map texture from shader properties
            sampler2D _NormalMap;

            float2 PpparallaxMapping(float2 texCoord, float3 viewDir) 
            {
                 float layerDepth = 0.1;
                 float currentLayerDepth = 1.0;
                 //float currentH = tex2D(_HeightMap, texCoord).r;
                 float2 p = viewDir.xy/viewDir.z * _HeightMapScale;// * (1. - currentH);
                 //return texCoord - p; 
                 float2 deltaP = p * layerDepth;

                 float2 currentTC = texCoord;
                 float currentH = tex2D(_HeightMap, currentTC).r;
                 if (currentLayerDepth <= currentH) {
                     return texCoord;
                 }
                 while (currentLayerDepth > currentH) {
                     currentTC -= deltaP;
                     currentH = tex2D(_HeightMap, currentTC).r;
                     currentLayerDepth -= layerDepth;
                     if (currentLayerDepth < -1) {
                         return float2(0, 0);
                     }
                 }                   

                 float2 prevTC = currentTC + deltaP;
                 float afterDepth = currentLayerDepth + layerDepth - tex2D(_HeightMap, prevTC).r;
                 float beforeDepth = currentH - currentLayerDepth;

                 float weight = afterDepth / (afterDepth + beforeDepth);
                 return prevTC * (1.0 - weight) + currentTC * weight;
            };

            float2 ParallaxMapping(float2 texCoords, float3 viewDir)
            { 
                const float step = 0.01;
                float currentH = 1.0;
    
                float heightMapH = tex2D(_HeightMap, texCoords).r;   
                if (currentH <= heightMapH) 
                {
                    return texCoords;
                } 
                float2 deltaP = viewDir.xy / viewDir.z * _HeightMapScale * step;

                while (currentH > heightMapH && currentH > 0)
                {
                    texCoords -= deltaP;
                    heightMapH = tex2D(_HeightMap, texCoords).r;  
                    currentH -= step;  
                }       

                float2 previousTexCoords = texCoords + deltaP;
                float prevoiusHeightMapH = tex2D(_HeightMap, previousTexCoords).r;
                float wA = currentH - prevoiusHeightMapH + step;
                float wB = heightMapH - currentH;
                float w = wA / (wA + wB);
                return texCoords * w + previousTexCoords * (1 - w);
            }
        
            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDirection = normalize(i.worldPos - _WorldSpaceCameraPos);
                float3 viewDir;
                viewDir.x = dot(float3(i.tspace0.x, i.tspace1.x, i.tspace2.x), viewDirection);
                viewDir.y = dot(float3(i.tspace0.y, i.tspace1.y, i.tspace2.y), viewDirection);
                viewDir.z = dot(float3(i.tspace0.z, i.tspace1.z, i.tspace2.z), viewDirection);
                viewDir /= viewDir.z;
                i.uv = ParallaxMapping(i.uv, viewDir); 
                // sample the normal map, and decode from the Unity encoding
                half3 tnormal = UnpackNormal(tex2D(_NormalMap, i.uv));
                // transform normal from tangent to world space
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, tnormal);
                worldNormal.y = dot(i.tspace1, tnormal);
                worldNormal.z = dot(i.tspace2, tnormal);

                half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(worldNormal, 1));

                fixed4 col = 0;
                col.rgb = tex2D(_MainTex, i.uv).rgb * light;
                return col;
            }
            ENDCG
        }
    }
}