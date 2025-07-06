/*
const int clrwl_shadowOpaque0Target = 0;
*/

#if SHADOW_QUALITY >= 1
/*
const int clrwl_shadowOpaque1Target = 1;
*/
#endif

/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

flat in vec3 sunVec, upVec;

in vec4 position;

//Pipeline Constants//

//Common Variables//
float SdotU = dot(sunVec, upVec);
float sunVisibility = clamp(SdotU + 0.0625, 0.0, 0.125) / 0.125;

//Common Functions//
void DoNaturalShadowCalculation(inout vec4 color1, inout vec4 color2) {
    color1.rgb *= flw_vertexColor.rgb;
    color1.rgb = mix(vec3(1.0), color1.rgb, pow(color1.a, (1.0 - color1.a) * 0.5) * 1.05);
    color1.rgb *= 1.0 - pow(color1.a, 64.0);
    color1.rgb *= 0.2; // Natural Strength

    color2.rgb = normalize(color1.rgb) * 0.5;
}

//Includes//

//Program//
void main() {
    flw_sampleColor = texture(flw_diffuseTex, flw_vertexTexCoord);
    flw_fragColor = flw_vertexColor * flw_sampleColor;
    flw_fragOverlay = flw_vertexOverlay;
    flw_fragLight = flw_vertexLight;

    flw_materialFragment();

    vec4 color1 = flw_fragColor;

    #if SHADOW_QUALITY >= 1
        vec4 color2 = color1; // Light Shaft Color

        color2.rgb *= 0.25; // Natural Strength

        #if defined LIGHTSHAFTS_ACTIVE && LIGHTSHAFT_BEHAVIOUR == 1 && defined OVERWORLD
            float positionYM = position.y;
        #endif

        DoNaturalShadowCalculation(color1, color2);
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = color1; // Shadow Color

    #if SHADOW_QUALITY >= 1
        #if defined LIGHTSHAFTS_ACTIVE && LIGHTSHAFT_BEHAVIOUR == 1 && defined OVERWORLD
            color2.a = 0.25 + max0(positionYM * 0.05); // consistencyMEJHRI7DG
        #endif

        /* DRAWBUFFERS:01 */
        gl_FragData[1] = color2; // Light Shaft Color
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

flat out vec3 sunVec, upVec;

out vec4 position;

//Pipeline Constants//
#if COLORED_LIGHTING_INTERNAL > 0
    #extension GL_ARB_shader_image_load_store : enable
#endif

//Attributes//

//Common Variables//
#if COLORED_LIGHTING_INTERNAL > 0
    writeonly uniform uimage3D voxel_img;

    #ifdef PUDDLE_VOXELIZATION
        writeonly uniform uimage2D puddle_img;
    #endif
#endif

//Common Functions//

//Includes//
#include "/lib/util/spaceConversion.glsl"

#if COLORED_LIGHTING_INTERNAL > 0
    #include "/lib/misc/voxelization.glsl"

    #ifdef PUDDLE_VOXELIZATION
        #include "/lib/misc/puddleVoxelization.glsl"
    #endif
#endif

//Program//
void main() {
    sunVec = GetSunVector();
    upVec = normalize(flw_view[1].xyz);

    position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

    #if COLORED_LIGHTING_INTERNAL > 0
        if (gl_VertexID % 4 == 0) {
            UpdateVoxelMap(mat);
            #ifdef PUDDLE_VOXELIZATION
                UpdatePuddleVoxelMap(mat);
            #endif
        }
    #endif

    gl_Position = shadowProjection * shadowModelView * position;

    float lVertexPos = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
    float distortFactor = lVertexPos * shadowMapBias + (1.0 - shadowMapBias);
    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;
}

#endif
