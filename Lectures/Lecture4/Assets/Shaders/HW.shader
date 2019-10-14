Shader "0_Custom/HW"
{   
    
    Properties
    {
        _Shininess("Shininess", float) = 1000
        _Cubemap ("Cubemap", CUBE) = "" {} 
        _Samples ("Samples", int) = 100
        _DiffusePower("Diffuse power", float) = 1
        _SpecularPower("Specular power", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
            
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
           
            static const float M_PI = 3.1415926;
            struct appdata
            {
                float4 vertex : POSITION;
                fixed3 normal : NORMAL;
            };

            struct v2f
            {
                float4 clip : SV_POSITION;
                float4 pos : TEXCOORD1;
                fixed3 normal : NORMAL;
            };

            samplerCUBE _Cubemap;
            int _Samples;
            float _DiffusePower;
            float _SpecularPower;
            float _Shininess;

            uint hash(uint s)
            {
                s ^= 2747636419u;
                s *= 2654435769u;
                s ^= s >> 16;
                s *= 2654435769u;
                s ^= s >> 16;
                s *= 2654435769u;
                return s;
            }
            
            float random(uint seed)
            {
                return float(hash(seed)) / 4294967295.0;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            //https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
            //Lighting GetPointLight( PointLight light, float3 pos3D, float3 viewDir, float3 normal )
            float f(float3 w, v2f i)
            {
                float3 lightDir = normalize(w);
                float3 normal = normalize(i.normal);
                
                //Intensity of the diffuse light. Saturate to keep within the 0-1 range.
                float NdotL = dot(normal, lightDir);
                float intensity = saturate(NdotL);

                // Calculate the diffuse light factoring in light color, power and the attenuation
                float diffuse = intensity * _DiffusePower;

                //Calculate the half vector between the light vector and the view vector.
                //This is typically slower than calculating the actual reflection vector
                // due to the normalize function's reciprocal square root
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.pos.xyz);
                float3 H = normalize(lightDir + viewDir);

                //Intensity of the specular light
                float NdotH = dot(normal, H);
                intensity = pow(saturate(NdotH), _Shininess);

                //Sum up the specular light factoring
                float specular = intensity * _SpecularPower;
                
                return diffuse + specular;
            }
                       
            float3 randomOnSemisphere(fixed3 normal, uint seed)
            {
                  float theta = 2 * M_PI * random(2 * seed);
                  float phi = acos(1 - 2 * random(2 * seed + 1));
                  float3 result = float3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
                  if (dot(normal, result) < 0)
                  {
                      result = -result;
                  }
                  return result;
            }
                       
            fixed4 frag(v2f x) : SV_Target
            {
                float3 normal = normalize(x.normal);
                float fSum = 0;
                float3 fColorSum = float3(0, 0, 0);
                for (uint i = 0; i < _Samples; i++)
                {
                    float3 w = normalize(randomOnSemisphere(normal, i));
                    float fValue = f(w, x);
                    fSum += fValue;
                    fColorSum += fValue * texCUBE(_Cubemap, w).rgb;
                }
                return float4(fColorSum / fSum, 1.0);
            }
            ENDCG
        }
    }
}