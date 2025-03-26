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
        float4 vPositionPs        : SV_Position;
    #endif
    #if ( ( PROGRAM == VFX_PROGRAM_PS ) )
        float4 vPositionSs        : SV_Position;
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
    RenderState( DepthWriteEnable, false );
    RenderState( DepthEnable, false );
    
    //Texture2D g_tColorBuffer < Attribute( "ColorBuffer" ); SrgbRead( true ); >;
    StructuredBuffer<SphereDef> Spheres < Attribute("Spheres"); >;
    int NumSpheres < Attribute("NumSpheres"); >;
    
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

    float4 MainPs( PixelInput i ) : SV_Target0
    {
        float3 vScenePositionWs = Depth::GetWorldPosition( i.vPositionSs.xy );
        
        Ray ray;
        ray.origin = g_vCameraPositionWs;
        ray.dir = normalize(vScenePositionWs - ray.origin);
        //return float4( ray.dir, 1 );
        return float4(CalculateRayCollision( ray ).hit, 0);
    }
}