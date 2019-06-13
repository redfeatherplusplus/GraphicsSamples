//----------------------------------------------------------------------------------
// File:        es3aep-kepler\TerrainTessellation\assets\shaders/terrain_tessellation.glsl
// SDK Version: v3.00 
// Email:       gameworks@nvidia.com
// Site:        http://developer.nvidia.com/
//
// Copyright (c) 2014-2015, NVIDIA CORPORATION. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//  * Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//  * Neither the name of NVIDIA CORPORATION nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//----------------------------------------------------------------------------------
// Version tag will be added in code
#extension GL_ARB_tessellation_shader : enable

#define PROCEDURAL_TERRAIN 1
#define NORMAL_FROM_HEIGHT_KERNEL 0

#UNIFORMS
#line 8
layout(quads, fractional_even_spacing, cw) in;

in gl_PerVertex {
    vec4 gl_Position;
} gl_in[];

layout(location=1) in block {
    mediump vec2 texCoord;
    vec2 tessLevelInner;
} In[];

out gl_PerVertex {
    vec4 gl_Position;
};

layout(location=1) out block {
    vec3 vertex;
    vec3 vertexEye;
    vec3 normal;
} Out;

uniform sampler2D terrainTex;

void main(){

    vec3 pos = gl_in[0].gl_Position.xyz;
    pos.xz += gl_TessCoord.xy * tileSize.xz;

#if PROCEDURAL_TERRAIN
    // calculate terrain height procedurally
    float h = terrain(pos.xz);
    vec3 n = vec3(0, 1, 0);
    pos.y = h;

#if NORMAL_FROM_HEIGHT_KERNEL

    // Should be distance from one texel to another in same units as heightmap.
    float sample_dist = 0.0001; 

    mat3 height_kernel;
    vec3 height_normals[8];
    int normal_index = 0;

    for(int i=0; i<3; i++)
    {
        for(int j=0; j<3; j++) 
        {
            float height_sample_x = pos.x + (i - 1) * sample_dist * tileSize.x; 
            float height_sample_z = pos.z + (j - 1) * sample_dist * tileSize.z; 
            // height_sample_x = clamp(height_sample_x, 0.0, 1.0); 
            // height_sample_z = clamp(height_sample_z, 0.0, 1.0); 
            vec3 height_sample = vec3(height_sample_x, 0.0, height_sample_z);
            height_kernel[i][j] = terrain(height_sample.xz);

            if (i != 1 || j != 1)
            {
                height_sample.y = height_kernel[i][j];

                // The height y-axis and new sample point gives us a plane.
                // The vector from original to new sample lies on that plane.
                // The vector perpendicular the that vector can be used as a normal.
                vec3 vec_on_height_sample_plane = vec3(height_sample.xy - pos.xy, 10);
                vec3 normal_height_sample_plane = cross(vec_on_height_sample_plane, height_sample);
                vec3 to_new_sample = height_sample - pos;
                vec3 height_normal = height_sample.y > pos.y ?
                                     normalize(cross(normal_height_sample_plane, to_new_sample)) :
                                     normalize(cross(to_new_sample, normal_height_sample_plane));
                height_normals[normal_index] = height_sample.y == pos.y ? vec3(0.0, 1.0, 0.0) : height_normal;
                normal_index++;
            }
        }
    }

    vec3 generated_normal = vec3(0, 0, 0);
    for(int i=0; i<8; i++)
    {
        generated_normal += height_normals[i];
    }
    generated_normal = normalize(generated_normal);

    // calculate normal
    vec2 triSize = tileSize.xz / In[0].tessLevelInner;
    vec3 pos_dx = pos.xyz + vec3(triSize.x, 0.0, 0.0);
    vec3 pos_dz = pos.xyz + vec3(0.0, 0.0, triSize.y);
    pos_dx.y = terrain(pos_dx.xz);
    pos_dz.y = terrain(pos_dz.xz);
    n = normalize(cross(pos_dz - pos.xyz, pos_dx - pos.xyz));
    n = generated_normal;

#else

    // calculate normal
    vec2 triSize = tileSize.xz / In[0].tessLevelInner;
    vec3 pos_dx = pos.xyz + vec3(triSize.x, 0.0, 0.0);
    vec3 pos_dz = pos.xyz + vec3(0.0, 0.0, triSize.y);
    pos_dx.y = terrain(pos_dx.xz);
    pos_dz.y = terrain(pos_dz.xz);
    n = normalize(cross(pos_dz - pos.xyz, pos_dx - pos.xyz));

#endif

#else

    // read from pre-calculated texture
    vec2 uv = In[0].texCoord + (vec2(1.0 / gridW, 1.0 / gridH) * gl_TessCoord.xy);
    vec4 t = texture2D(terrainTex, uv);
    float h = t.w;
    pos.y = t.w;
    vec3 n = t.xyz;
#endif

    Out.normal = n;

    Out.vertex = pos;
    Out.vertexEye = vec3(ModelView * vec4(pos, 1));  // eye space

    gl_Position = ModelViewProjection * vec4(pos, 1);
}
