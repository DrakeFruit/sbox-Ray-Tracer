using System;
using Sandbox.Rendering;

namespace Sandbox;

[Title( "Ray Trace" )]
[Category( "Rendering" )]
[Icon( "grain" )]
public sealed class RayTrace : PostProcess, Component.ExecuteInEditor
{
	[Property] int MaxBounces { get; set; }
	[Property] int RaysPerPixel { get; set; }
	[Property] Texture BlueNoise { get; set; }
	[Property, InlineEditor] public List<SphereDef> Spheres { get; set; } = [];

	int Frames = 0;

	IDisposable renderHook;

	protected override void OnEnabled()
	{
		Frames = 0;
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
		attributes.Set( "NumSpheres", Spheres.Count );
		attributes.Set( "MaxBounceCount", MaxBounces );
		attributes.Set( "RaysPerPixel", RaysPerPixel );
		attributes.Set( "BlueNoise", BlueNoise );
		attributes.Set( "FramesRendered", Frames );

		// Pass the FrameBuffer to the shader
		Graphics.GrabFrameTexture( "ColorBuffer", attributes );

		// Blit a quad across the entire screen with our custom shader
		Graphics.Blit( Material.FromShader( "shaders/raytrace.shader" ), attributes );
		Graphics.GrabFrameTexture( "FramePrev", attributes );
		Frames++;
	}

	public struct SphereDef
	{
		public Vector3 position { get; set; }
		public float radius { get; set; }
		[InlineEditor] public RayTracingMaterial material { get; set; }
	}
	
	public struct RayTracingMaterial
	{
		public Color color { get; set; }
		public Color emissionColor { get; set; }
		public float emissionStrength { get; set; }
	};
}
