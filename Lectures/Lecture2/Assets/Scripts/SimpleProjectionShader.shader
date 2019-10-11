Shader "Custom/BrokenShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        //_MainTex ("Albedo (RGB)", 2D) = "white" {}
        _XTex ("Albedo (RGB)", 2D) = "white" {}
        _YTex ("Albedo (RGB)", 2D) = "white" {}
        _ZTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0

            struct v2f
            {
                float4 pos : SV_POSITION;
                //float2 uv : TEXCOORD0;
		float2 zy : TEXCOORD0;
                float2 xz : TEXCOORD1;
                float2 xy : TEXCOORD2;
                fixed3 normal : NORMAL;
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                //o.uv = v.texcoord;
 		o.zy = v.vertex.zy;
                o.xz = v.vertex.xz;
                o.xy = v.vertex.xy;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            //sampler2D _MainTex;
	    sampler2D _XTex;
	    sampler2D _YTex;
	    sampler2D _ZTex;

            fixed4 frag (v2f i) : SV_Target
            {
                half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.normal,1));
                
		//fixed4 col = tex2D(_MainTex, i.uv);

		fixed4 cx = tex2D(_XTex, i.zy);
		fixed4 cy = tex2D(_YTex, i.xz);
		fixed4 cz = tex2D(_ZTex, i.xy);
//		fixed4 sumcxcycz = cx + cy + cz;
//		cx /= sumcxcycz;
//		cy /= sumcxcycz;
//		cz /= sumcxcycz;
		fixed3 n = pow(i.normal, 4);
// 		fixed4 col = cx * n.x + cy * n.y + cz * n.z;
// 		fixed4 col = cx * pow(i.normal.x, 4) 
//                           + cy * pow(i.normal.y, 4)
//                           + cz * pow(i.normal.z, 4);
		float len = n.x + n.y + n.z;
		fixed4 col = cx * n.x / len + cy * n.y / len + cz * n.z / len;
                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
