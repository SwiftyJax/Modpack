/*
const int clrwl_coefficients0Rank = 3;

const int clrwl_accumulate0Coefficients = 0;

const int clrwl_accumulate0Format = RGBA16F;
const int clrwl_opaque0Format = RGBA8;

const int clrwl_accumulate0Target = 0;
const int clrwl_opaque0Target = 6;
*/

#if BLOCK_REFLECT_QUALITY >= 2 && RP_MODE != 0
/*
const int clrwl_opaque1Format = RGBA8_SNORM;
const int clrwl_opaque1Target = 5;
*/
#endif

//////////////////////////////////
// Complementary Base by EminGT //
//////////////////////////////////

#define glColor flw_fragColor

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

flat in vec3 upVec, sunVec, northVec, eastVec;
in vec3 normal;

#if defined GENERATED_NORMALS || defined COATED_TEXTURES || defined POM
    in vec2 signMidCoordPos;
    flat in vec2 absMidCoordPos;
#endif

#if defined GENERATED_NORMALS || defined CUSTOM_PBR
    flat in vec3 binormal, tangent;
#endif

#ifdef POM
    in vec3 viewVector;

    in vec4 vTexCoordAM;
#endif

//Pipeline Constants//

//Common Variables//
float NdotU = dot(normal, upVec);
float NdotUmax0 = max(NdotU, 0.0);
float SdotU = dot(sunVec, upVec);
float sunFactor = SdotU < 0.0 ? clamp(SdotU + 0.375, 0.0, 0.75) / 0.75 : clamp(SdotU + 0.03125, 0.0, 0.0625) / 0.0625;
float sunVisibility = clamp(SdotU + 0.0625, 0.0, 0.125) / 0.125;
float sunVisibility2 = sunVisibility * sunVisibility;
float shadowTimeVar1 = abs(sunVisibility - 0.5) * 2.0;
float shadowTimeVar2 = shadowTimeVar1 * shadowTimeVar1;
float shadowTime = shadowTimeVar2 * shadowTimeVar2;

#ifdef OVERWORLD
    vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
    vec3 lightVec = sunVec;
#endif

#if defined GENERATED_NORMALS || defined CUSTOM_PBR
    mat3 tbnMatrix = mat3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
    );
#endif

//Common Functions//

vec3 FlwViewToPlayer(vec3 viewPos)
{
    return mat3(flw_viewInverse) * viewPos + flw_viewInverse[3].xyz - flw_cameraPos;
}

vec2 Flw_GetLightMapCoordinates(vec2 lm) {
    return clamp(((lm * 16.0 / 15.0) - 0.03125) * 1.06667, 0.0, 1.0);
}

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/lighting/mainLighting.glsl"

#ifdef TAA
    #include "/lib/antialiasing/jitter.glsl"
#endif

#if defined GENERATED_NORMALS || defined COATED_TEXTURES
    #include "/lib/util/miplevel.glsl"
#endif

#ifdef GENERATED_NORMALS
    #include "/lib/materials/materialMethods/generatedNormals.glsl"
#endif

#ifdef COATED_TEXTURES
    #include "/lib/materials/materialMethods/coatedTextures.glsl"
#endif

#if IPBR_EMISSIVE_MODE != 1
    #include "/lib/materials/materialMethods/customEmission.glsl"
#endif

#ifdef CUSTOM_PBR
    #define texCoord flw_vertexTexCoord
    #include "/lib/materials/materialHandling/customMaterials.glsl"
    #undef texCoord
#endif

#ifdef COLOR_CODED_PROGRAMS
    #include "/lib/misc/colorCodedPrograms.glsl"
#endif

#ifdef PORTAL_EDGE_EFFECT
    #include "/lib/misc/voxelization.glsl"
#endif

//Program//
void main() {
    flw_sampleColor = texture(flw_diffuseTex, flw_vertexTexCoord);
    flw_fragColor = flw_vertexColor * flw_sampleColor;
    flw_fragOverlay = flw_vertexOverlay;
    flw_fragLight = flw_vertexLight;

    flw_materialFragment();
    flw_shaderLight();

    vec4 color = flw_fragColor;
    vec2 lmCoord = Flw_GetLightMapCoordinates(flw_fragLight);

    #ifdef GENERATED_NORMALS
        vec3 colorP = color.rgb;
    #endif

    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    #ifdef TAA
        vec3 viewPos = ScreenToView(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
    #else
        vec3 viewPos = ScreenToView(screenPos);
    #endif
    float lViewPos = length(viewPos);
    vec3 playerPos = FlwViewToPlayer(viewPos);

    bool noSmoothLighting = false, noDirectionalShading = false;
    float smoothnessD = 0.0, skyLightFactor = 0.0, materialMask = 0.0;
    float smoothnessG = 0.0, highlightMult = 1.0, emission = 0.0, noiseFactor = 1.0;
    vec2 lmCoordM = lmCoord;
    vec3 normalM = normal, geoNormal = normal, shadowMult = vec3(1.0);
    vec3 worldGeoNormal = normalize(ViewToPlayer(geoNormal * 10000.0));

    #ifdef IPBR
        #include "/lib/materials/materialHandling/blockEntityMaterials.glsl"

        #if IPBR_EMISSIVE_MODE != 1
            emission = GetCustomEmissionForIPBR(color, emission);
        #endif
    #else
        #ifdef CUSTOM_PBR
            GetCustomMaterials(color, normalM, lmCoordM, NdotU, shadowMult, smoothnessG, smoothnessD, highlightMult, emission, materialMask, viewPos, lViewPos);
        #endif

        noSmoothLighting = true;
    #endif

    #ifdef GENERATED_NORMALS
        GenerateNormals(normalM, colorP);
    #endif

    #ifdef COATED_TEXTURES
        CoatTextures(color.rgb, noiseFactor, playerPos, false);
    #endif

    DoLighting(color, shadowMult, playerPos, viewPos, lViewPos, geoNormal, normalM, 0.5,
               worldGeoNormal, lmCoordM, noSmoothLighting, noDirectionalShading, false,
               false, 0, smoothnessG, highlightMult, emission);

    #ifdef PBR_REFLECTIONS
        #ifdef OVERWORLD
            skyLightFactor = pow2(max(lmCoord.y - 0.7, 0.0) * 3.33333);
        #else
            skyLightFactor = dot(shadowMult, shadowMult) / 3.0;
        #endif
    #endif

    #ifdef COLOR_CODED_PROGRAMS
        ColorCodeProgram(color, blockEntityId);
    #endif

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(smoothnessD, materialMask, skyLightFactor, 1.0);

    #if BLOCK_REFLECT_QUALITY >= 2 && RP_MODE != 0
        /* DRAWBUFFERS:065 */
        gl_FragData[2] = vec4(mat3(gbufferModelViewInverse) * normalM, 1.0);
    #endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

flat out vec3 upVec, sunVec, northVec, eastVec;
out vec3 normal;

#if defined GENERATED_NORMALS || defined COATED_TEXTURES || defined POM
    out vec2 signMidCoordPos;
    flat out vec2 absMidCoordPos;
#endif

#if defined GENERATED_NORMALS || defined CUSTOM_PBR
    flat out vec3 binormal, tangent;
#endif

#ifdef POM
    out vec3 viewVector;

    out vec4 vTexCoordAM;
#endif

//Attributes//

//Common Variables//

//Common Functions//

//Includes//
#ifdef TAA
    #include "/lib/antialiasing/jitter.glsl"
#endif

//Program//
void main() {
    gl_Position = ftransform();
    #ifdef TAA
        gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
    #endif

    normal = normalize(clrwl_normal * flw_vertexNormal);

    upVec = normalize(flw_view[1].xyz);
    eastVec = normalize(flw_view[0].xyz);
    northVec = normalize(flw_view[2].xyz);
    sunVec = GetSunVector();

    if (normal != normal) normal = -upVec; // Mod Fix: Fixes Better Nether Fireflies

    #if defined GENERATED_NORMALS || defined COATED_TEXTURES || defined POM
        vec2 midCoord = flw_vertexMidTexCoord;
        vec2 texMinMidCoord = flw_vertexTexCoord - flw_vertexMidTexCoord;
        signMidCoordPos = sign(texMinMidCoord);
        absMidCoordPos  = abs(texMinMidCoord);
    #endif

    #if defined GENERATED_NORMALS || defined CUSTOM_PBR
        binormal = normalize(clrwl_normal * cross(flw_vertexTangent.xyz, flw_vertexNormal.xyz) * flw_vertexTangent.w);
        tangent  = normalize(clrwl_normal * flw_vertexTangent.xyz);
    #endif

    #ifdef POM
        mat3 tbnMatrix = mat3(
            tangent.x, binormal.x, normal.x,
            tangent.y, binormal.y, normal.y,
            tangent.z, binormal.z, normal.z
        );

        viewVector = tbnMatrix * (flw_view * flw_vertexPos).xyz;

        vTexCoordAM.zw  = abs(texMinMidCoord) * 2;
        vTexCoordAM.xy  = min(flw_vertexTexCoord, midCoord - texMinMidCoord);
    #endif
}

#endif
