using Godot;
using Godot.Collections;
using System;

[Tool]
[GlobalClass]
public partial class PSX_Manager : Node
{
    CompositorEffect psxCompositorEffect;
    ShaderMaterial psxCanvasMaterial;

    private Vector2 fogRange = new Vector2(10, 20);
    [Export] Vector2 FogRange
    {
        get
            {
		        return fogRange;
            }
        set
	    {
            RenderingServer.GlobalShaderParameterSet("fog_range", value);
            fogRange = value;
        }
    }

    private Color fogColor = Colors.White;
    [Export] Color FogColor
    {
        get
        {
            return fogColor;
        }
        set
        {
            RenderingServer.GlobalShaderParameterSet("fog_color", value);
            fogColor = value;
        }
    }

    private bool fogBlack;
    [Export] bool FogBlack
    {
        get
	    {
		    return fogBlack;
	    }
	    set
	    {
            RenderingServer.GlobalShaderParameterSet("fog_black", value);
            fogBlack = value;
        }
    }

    static string sceneCurrent;

    public override void _Ready()
    {
        CallDeferred("Setup");
    }

    public override void _Process(double delta)
    {
        if (Engine.IsEditorHint())
        {
            if (sceneCurrent != EditorInterface.Singleton.GetEditedSceneRoot().SceneFilePath)
            {
                ApplySettings();
                sceneCurrent = EditorInterface.Singleton.GetEditedSceneRoot().SceneFilePath;
            }
        }
    }


    void Setup()
    {
        ApplySettings();

        GetProjectSettings();
        SetupShaderGlobals();
    }


    void GetProjectSettings()
    {
        var compositor_path = "psx/compositor_effect_path";
        var canvas_path = "psx/canvas_material_path";

        string compositor_setting = (string)ProjectSettings.GetSetting(compositor_path);
        if (!ProjectSettings.HasSetting(compositor_path))
        {
            ProjectSettings.SetSetting(compositor_path, "");
            compositor_setting = "";
            GD.PrintRich("You can set [b]psx/compositor_effect_path[/b] in [b]project settings[/b] to be used by [b]PSX Manager[/b]");
        }
        if (compositor_setting != null && compositor_setting != "")
        {
            psxCompositorEffect = GD.Load((string)ProjectSettings.GetSetting(compositor_path)) as CompositorEffect;

        }
        string canvas_setting = (string)ProjectSettings.GetSetting(canvas_path);
        if (!ProjectSettings.HasSetting(canvas_path))
        {
            ProjectSettings.SetSetting(canvas_path, "");
            canvas_setting = "";
            GD.PrintRich("You can set [b]psx/canvas_material_path[/b] in [b]project settings[/b] to be used by [b]PSX Manager[/b]");
        }
        if (canvas_setting != null && canvas_setting != "")
        {
            psxCanvasMaterial = GD.Load((string)ProjectSettings.GetSetting(canvas_path)) as ShaderMaterial;
        }
    }


    void SetupShaderGlobals()
    {
        Godot.Collections.Dictionary globals = new();
        globals["resolution"] = new Vector2I(320, 240);
        globals["snap"] = 0.5;
        globals["cull_dist"] = 0.5;
        globals["fog_black"] = false;
        globals["fog_range"] = new Vector2(10, 20);
        globals["fog_color"] = Colors.White;

        foreach (string k in globals.Keys)
        {
            if (RenderingServer.GlobalShaderParameterGet(k).VariantType == Variant.Type.Nil)
            {
                GD.PrintRich($"Shader global is missing - id: [b]{k}[/b], type: [b]{globals[k].GetType().ToString()}[/b], add it in [b]Project settings -> Globals -> Shader globals[/b]: [b]");
            }
        }
    }
    

    void ApplySettings()
    {
        RenderingServer.GlobalShaderParameterSet("fog_range", FogRange);
        RenderingServer.GlobalShaderParameterSet("fog_color", FogColor);
        RenderingServer.GlobalShaderParameterSet("fog_black", FogBlack);
    }


    public void SetResolution(Vector2 resolution)
    {
        RenderingServer.GlobalShaderParameterSet("resolution", resolution);

        if (psxCompositorEffect != null)
        {
            psxCompositorEffect.Set("resoulution", resolution);
        } 
    }


    public void SetColordepth(int depth)
    {
        if (psxCompositorEffect != null)
        {
            psxCompositorEffect.Set("color_depth", depth);
        }

        if (psxCanvasMaterial != null)
        {
            psxCanvasMaterial.SetShaderParameter("color_depth", depth);
        }
    }

    public void SetDitherStrength(int strength)
    {
        if (psxCompositorEffect != null)
        {
            psxCompositorEffect.Set("dither_strength", strength);
        }

        if (psxCanvasMaterial != null)
        {
            psxCanvasMaterial.SetShaderParameter("dither_strength", strength);
        }
    }


    public void SetDitherStrengthTexture(Texture2D texture)
    {
        if (psxCompositorEffect != null)
        {
            psxCompositorEffect.Set("dither", texture);
        }

        if (psxCanvasMaterial != null)
        {
            psxCanvasMaterial.SetShaderParameter("dither_texture", texture);
        }
    }
}
