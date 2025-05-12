vec3 ApplyMultiColoredBlocklight(vec3 blocklightCol, vec3 screenPos, vec3 playerPos, float lmCoord) {
    float ACLDecider = 1.0;
    vec4 coloredLight = texture2D(colortex9, screenPos.xy);
    float entityMask = step(0.5, sqrt3(coloredLight.a)) * step(0.1, lmCoord);
    #if MCBL_MAIN_DEFINE == 2 && COLORED_LIGHTING_INTERNAL != 0
        vec3 absPlayerPos = abs(playerPos);
        float maxPlayerPos = max(absPlayerPos.x, max(absPlayerPos.y * 2.0, absPlayerPos.z));
        ACLDecider = pow2(min1(maxPlayerPos / min(effectiveACLdistance, far) * 2.0)); // this is to make the effect fade at the edge of ACL range
        if (ACLDecider < 0.5 && entityMask < 0.5) return blocklightCol;
    #endif
    
    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    cameraOffset *= float(screenPos.z * 2.0 - 1.0 > 0.56);

    if (screenPos.z > 0.56) {
        screenPos.xy = Reprojection(screenPos, cameraOffset);
    }
    vec3 coloredLightNormalized = normalize(coloredLight.rgb + 0.00001);

    // do luminance correction for a seamless transition from the default blocklight color
    coloredLightNormalized *= GetLuminance(blocklightCol) / GetLuminance(coloredLightNormalized);

    float coloredLightMix = min1((coloredLight.r + coloredLight.g + coloredLight.b) * 2048);
    coloredLightMix = mix(0, coloredLightMix, mix(ACLDecider, 1.0, entityMask));

    // coloredLightNormalized = vec3(2,0,0);

    return mix(blocklightCol, coloredLightNormalized, coloredLightMix * MCBL_INFLUENCE);
}