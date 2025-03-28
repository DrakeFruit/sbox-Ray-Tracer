MODES
{
    Forward();
    Depth();
}

FEATURES
{
    #include "common/features.hlsl"
}

COMMON
{
	#include "common/shared.hlsl"
}

struct VertexInput
{
    #include "common/vertexinput.hlsl"
};

struct PixelInput
{
    float2 vTexCoord : TEXCOORD0;
    #if ( PROGRAM == VFX_PROGRAM_VS )
        float4 vPositionPs : SV_Position;
    #endif
    #if ( ( PROGRAM == VFX_PROGRAM_PS ) )
        float4 vPositionSs : SV_Position;
    #endif
};

VS
{
	PixelInput MainVs( VertexInput i )
    {
        PixelInput o;

        o.vPositionPs = float4( i.vPositionOs.xyz, 1.0f );

        return o;
    }
}

PS
{
    #include "postprocess/common.hlsl"
    #include "postprocess/functions.hlsl"
	#include "common/shared.hlsl"
    #include "common\classes\Motion.hlsl"
	Texture2D g_tPreviousFrame < Attribute( "PreviousFrameTexture" ); SrgbRead( true ); >;
	Texture2D g_tCurrentFrame < Attribute( "CurrentFrameTexture" ); SrgbRead( true ); >;
    
    SamplerState BilinearClamp < Filter( MIN_MAG_MIP_LINEAR ); AddressU( CLAMP ); AddressV( CLAMP ); AddressW( CLAMP ); >;

	float4 MainPs( PixelInput i ) : SV_Target0
	{
		//return Motion::TemporalFilter( CalculateViewportUv( i.vPositionSs.xy ), g_tCurrentFrame, g_tPreviousFrame, 20000 );
	    return g_tPreviousFrame.Sample( BilinearClamp, CalculateViewportUv( i.vPositionSs.xy ) ).rgba + g_tCurrentFrame.Sample( BilinearClamp, CalculateViewportUv( i.vPositionSs.xy ) ).rgba;
	}
}
