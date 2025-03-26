using System;

namespace Sandbox;

[Title( "Ray Trace" )]
[Category( "Rendering" )]
[Icon( "grain" )]
public sealed class RayTrace : PostProcess, Component.ExecuteInEditor
{
	[Property] List<SphereDef> Spheres { get; set; }

	IDisposable renderHook;

	protected override void OnEnabled()
	{
		renderHook = Camera.AddHookBeforeOverlay( "My Post Processing", 1000, RenderEffect );
	}

	protected override void OnDisabled()
	{
		renderHook?.Dispose();
		renderHook = null;
	}

	RenderAttributes attributes = new();

	public void RenderEffect( SceneCamera camera )
	{
		if ( !camera.EnablePostProcessing )
			return;

		// Properties
		// float Deg2Rad = (float)Math.PI * 2 / 360;
		// float planeHeight = camera.ZNear * MathF.Tan(camera.FieldOfView * 0.5f * Deg2Rad) * 2;
		// float planeWidth = planeHeight * (camera.Rect.Width / camera.Rect.Height);
		//
		// attributes.Set("ViewParams", new Vector3(planeWidth, planeHeight, camera.ZNear) );
		// attributes.Set( "CamLocalToWorldMatrix", Matrix.CreateRotation( camera.Rotation ) * Matrix.CreateTranslation( camera.Position ) );
		GpuBuffer<SphereDef> SphereBuffer = new( Spheres.Count );
		SphereBuffer.SetData( Spheres );
		
		attributes.Set( "Spheres", SphereBuffer );

		// Pass the FrameBuffer to the shader
		Graphics.GrabFrameTexture( "ColorBuffer", attributes );

		// Blit a quad across the entire screen with our custom shader
		Graphics.Blit( Material.FromShader( "shaders/raytrace.shader" ), attributes );
	}

	struct SphereDef
	{
		Vector3 position;
		float radius;
		RayTracingMaterial material;
	}
	
	struct RayTracingMaterial
	{
		Color color;
	};
}
