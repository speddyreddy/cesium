attribute vec4 position3DAndHeight;
attribute vec2 textureCoordinates;

uniform vec3 u_center3D;
uniform mat4 u_modifiedModelView;
uniform vec4 u_tileExtent;

// Uniforms for 2D Mercator projection
uniform vec2 u_southAndNorthLatitude;
uniform vec3 u_southMercatorYLowAndHighAndOneOverHeight;

varying vec3 v_positionMC;
varying vec3 v_positionEC;

varying vec2 v_textureCoordinates;

// These functions are generated at runtime.
vec4 getPosition(vec3 position3DWC);
float get2DYPositionFraction();

vec4 getPosition3DMode(vec3 position3DWC)
{
    return czm_projection * (u_modifiedModelView * vec4(position3DAndHeight.xyz, 1.0));
}

float get2DMercatorYPositionFraction()
{
    // The width of a tile at level 11, in radians and assuming a single root tile, is
    //   2.0 * czm_pi / pow(2.0, 11.0)
    // We want to just linearly interpolate the 2D position from the texture coordinates
    // when we're at this level or higher.  The constant below is the expression
    // above evaluated and then rounded up at the 4th significant digit.
    const float maxTileWidth = 0.003068;
    float positionFraction = textureCoordinates.y;
    float southLatitude = u_southAndNorthLatitude.x;
    float northLatitude = u_southAndNorthLatitude.y;
    if (northLatitude - southLatitude > maxTileWidth)
    {
        float southMercatorYLow = u_southMercatorYLowAndHighAndOneOverHeight.x;
        float southMercatorYHigh = u_southMercatorYLowAndHighAndOneOverHeight.y;
        float oneOverMercatorHeight = u_southMercatorYLowAndHighAndOneOverHeight.z;

        float currentLatitude = mix(southLatitude, northLatitude, textureCoordinates.y);
        currentLatitude = clamp(currentLatitude, -czm_webMercatorMaxLatitude, czm_webMercatorMaxLatitude);
        positionFraction = czm_latitudeToWebMercatorFraction(currentLatitude, southMercatorYLow, southMercatorYHigh, oneOverMercatorHeight);
    }    
    return positionFraction;
}

float get2DGeographicYPositionFraction()
{
    return textureCoordinates.y;
}

vec4 getPositionPlanarEarth(vec3 position3DWC, float height2D)
{
    float yPositionFraction = get2DYPositionFraction();
    vec4 rtcPosition2D = vec4(height2D, mix(u_tileExtent.st, u_tileExtent.pq, vec2(textureCoordinates.x, yPositionFraction)), 1.0);  
    return czm_projection * (u_modifiedModelView * rtcPosition2D);
}

vec4 getPosition2DMode(vec3 position3DWC)
{
    return getPositionPlanarEarth(position3DWC, 0.0);
}

vec4 getPositionColumbusViewMode(vec3 position3DWC)
{
    return getPositionPlanarEarth(position3DWC, position3DAndHeight.w);
}

vec4 getPositionMorphingMode(vec3 position3DWC)
{
    // We do not do RTC while morphing, so there is potential for jitter.
    // This is unlikely to be noticable, though.
    float yPositionFraction = get2DYPositionFraction();
    vec4 position2DWC = vec4(0.0, mix(u_tileExtent.st, u_tileExtent.pq, vec2(textureCoordinates.x, yPositionFraction)), 1.0);
    vec4 morphPosition = czm_columbusViewMorph(position2DWC, vec4(position3DWC, 1.0), czm_morphTime);
    return czm_modelViewProjection * morphPosition;
}

void main() 
{
    vec3 position3DWC = position3DAndHeight.xyz + u_center3D;

    gl_Position = getPosition(position3DWC);
    
#ifdef SHOW_REFLECTIVE_OCEAN
    v_positionEC = (czm_modelView3D * vec4(position3DWC, 1.0)).xyz;
    v_positionMC = position3DWC;                                 // position in model coordinates
#endif

    v_textureCoordinates = textureCoordinates;
}
