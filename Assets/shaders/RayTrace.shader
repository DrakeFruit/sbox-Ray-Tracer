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
    struct Ray
    {
        float3 origin;
        float3 dir;
    };
    
    struct RayTracingMaterial
    {
        float4 color;
        float4 emissionColor;
        float emissionStrength;
    };
    
    struct HitInfo
    {
        bool hit;
        float dist;
        float3 hitPoint;
        float3 normal;
        RayTracingMaterial material;
    };
    
    struct SphereDef
    {
        float3 position;
        float radius;
        RayTracingMaterial material;
    };
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
    RenderState( DepthWriteEnable, true );
    RenderState( DepthEnable, true );

    Texture2D g_tBlueNoise < Attribute( "BlueNoise" ); SrgbRead( true ); >;
    StructuredBuffer<SphereDef> Spheres < Attribute("Spheres"); >;
    
    int NumSpheres < Attribute("NumSpheres"); >;
    int MaxBounceCount < Attribute( "MaxBounceCount" ); >;
    int RaysPerPixel < Attribute( "RaysPerPixel" ); >;
    
    SamplerState BilinearClamp < Filter( MIN_MAG_MIP_LINEAR ); AddressU( CLAMP ); AddressV( CLAMP ); AddressW( CLAMP ); >;
    
    HitInfo RaySphere( Ray ray, float3 sphereCenter, float sphereRadius )
    {
        HitInfo hitInfo = (HitInfo)0;
        float3 offsetRayOrigin = ray.origin - sphereCenter;
        
        float a = dot( ray.dir, ray.dir );
        float b = 2 * dot( offsetRayOrigin, ray.dir );
        float c = dot( offsetRayOrigin, offsetRayOrigin ) - sphereRadius * sphereRadius;
        
        float discriminant = b * b - 4 * a * c;
        
        if ( discriminant >= 0 )
        {
            float dist = (-b - sqrt(discriminant)) / (2 * a);
            
            if ( dist >= 0 )
            {
                hitInfo.hit = true;
                hitInfo.dist = dist;
                hitInfo.hitPoint = ray.origin + ray.dir * dist;
                hitInfo.normal = normalize( hitInfo.hitPoint - sphereCenter );
            }
        }
        return hitInfo;
    }
    
    HitInfo CalculateRayCollision( Ray ray )
    {
        HitInfo closestHit = (HitInfo)0;
        closestHit.dist = 1.#INF;
        
        for ( int i = 0; i < NumSpheres; i++ )
        {
            SphereDef sphere = Spheres[i];
            HitInfo hitInfo = RaySphere( ray, sphere.position, sphere.radius );
            
            if ( hitInfo.hit && hitInfo.dist < closestHit.dist )
            {
                closestHit = hitInfo;
                closestHit.material = sphere.material;
            }
        }
        return closestHit;
    }
    
//    float RandomValue( inout uint state )
//    {
//        state = state * 747796405 + 2891336453;
//        uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
//        result = (result >> 22) ^ result;
//        return result / pow(2, 32);
//    }
//    
    float RandomValueNormalDistribution( float noise ) //somehow get a different random number each time
    {
        float theta = 2 * 3.1415926 * noise;
        float rho = sqrt( -2 * log(noise) );
        return rho * cos( theta );
    }
    
    float3 RandomDirection( float3 random )
    {
		float x = RandomValueNormalDistribution( random.r );
        float y = RandomValueNormalDistribution( random.g );
        float z = RandomValueNormalDistribution( random.b );
    
        return normalize( float3(x, y, z) );
    }
    
//    float3 RandomHemisphereDirection( float3 normal, float2 uv )
//    {
//        float3 dir = RandomDirection( uv, randomOffset );
//        return dir * sign( dot(normal, dir) );
//    }
    
    float3 Trace( Ray ray, float2 uv )
    {
        float3 random = g_tBlueNoise.Sample( g_sPointWrap, uv ).rgb;
        float3 incomingLight = 0;
        float3 rayColor = 1;
        
        for ( int i = 0; i <= MaxBounceCount; i++ )
        {
            HitInfo hitInfo = CalculateRayCollision( ray );
            if ( hitInfo.hit )
            {
                ray.origin = hitInfo.hitPoint;
                ray.dir = normalize( hitInfo.normal + RandomDirection( random ) );
                
                RayTracingMaterial mat = hitInfo.material;
                float3 emittedLight = mat.emissionColor.xyz * mat.emissionStrength;
                incomingLight += emittedLight * rayColor;
                rayColor *= mat.color.xyz;
            }
            else // Hit nothing, return skybox color
            {
                float3 ambientLight = AmbientLight::From( ray.origin, uv, ray.dir ); //TODO: fix skybox blurring or whatever
                incomingLight += ambientLight * rayColor;
                break;
            }
        }
        return incomingLight;
    }

    float4 MainPs( PixelInput i ) : SV_Target0
    {
//        uint2 numPixels = g_vViewportSize.xy;
//        uint2 pixelCoord = i.vPositionSs.xy * numPixels;
//        uint pixelIndex = pixelCoord.y * numPixels.x * pixelCoord.x;
//        uint rngState = pixelIndex + g_flTime * 8000;
        
        float3 vScenePositionWs = Depth::GetWorldPosition( i.vPositionSs.xy );
        
        Ray ray;
        ray.origin = g_vCameraPositionWs;
        ray.dir = normalize(vScenePositionWs - ray.origin);
        
        float3 totalIncomingLight = 0;
        
        for ( int rayIndex = 0; rayIndex < RaysPerPixel; rayIndex++ )
        {
            totalIncomingLight += Trace( ray, CalculateViewportUv( i.vPositionSs.xy ) );
        }
        
        float4 pixelColor = float4( totalIncomingLight / RaysPerPixel, 1 );
        
        //float4 old = g_tPrevFrame.Sample( BilinearClamp, CalculateViewportUv( i.vPositionSs.xy ) ).rgba;
		//float3 random = g_tBlueNoise.Sample( g_sPointWrap, CalculateViewportUv( i.vPositionSs.xy ) * 4 ).rgb;
        //return float4( Trace( ray, CalculateViewportUv( i.vPositionSs.xy ) ), 1 );
		return pixelColor;
        //return float4(AmbientLight::From( g_vCameraPositionWs, i.vPositionSs.xy, g_vCameraDirWs ), 0 );
    }
}