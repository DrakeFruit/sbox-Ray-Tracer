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
	
	Texture PrevTexture { get; set; }

	IDisposable renderHook;

	protected override void OnEnabled()
	{
		PrevTexture = Texture.CreateRenderTarget( "PreviousFrame", ImageFormat.RGBA8888, Screen.Size );
		renderHook = Camera.AddHookBeforeOverlay( "My Post Processing", 1000, RenderEffect );
	}

	protected override void OnDisabled()
	{
		renderHook?.Dispose();
		renderHook = null;
	}

	RenderAttributes attributes = new();
	RenderAttributes AccAttributes = new();

	public void RenderEffect( SceneCamera camera )
	{
		if ( !camera.EnablePostProcessing )
			return;
		
		GpuBuffer<SphereDef> SphereBuffer = new( Spheres.Count );
		SphereBuffer.SetData( Spheres );
		
		attributes.Set( "Spheres", SphereBuffer );
		attributes.Set( "NumSpheres", Spheres.Count );
		attributes.Set( "MaxBounceCount", MaxBounces );
		attributes.Set( "RaysPerPixel", RaysPerPixel );
		attributes.Set( "BlueNoise", BlueNoise );

		// Pass the FrameBuffer to the shader
		var currentFrame = Graphics.GrabFrameTexture( "ColorBuffer", AccAttributes );
		Graphics.RenderTarget = currentFrame;

		// Blit a quad across the entire screen with our custom shader
		Graphics.Blit( Material.FromShader( "shaders/raytrace.shader" ), attributes );
		Graphics.RenderTarget = null;

		AccAttributes.Set( "PreviousFrameTexture", PrevTexture );
		AccAttributes.Set( "CurrentFrameTexture", currentFrame.ColorTarget );
		
		Graphics.Blit( Material.FromShader( "shaders/accumulate.shader" ), AccAttributes );
		//Log.Info(PrevTexture);
		PrevTexture = currentFrame.ColorTarget;
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
