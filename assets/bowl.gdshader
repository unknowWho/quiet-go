shader_type spatial;
uniform sampler2D grain : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic,repeat_enable;
void fragment(){
    vec3 col=texture(grain,UV*vec2(2.0,0.42)).rgb;
    float v=dot(col,vec3(0.3,0.59,0.11));
    ALBEDO=mix(vec3(0.046,0.021,0.012),vec3(0.23,0.105,0.042),clamp(v*3.0,0.0,1.0));
    ROUGHNESS=0.29+texture(rough_tex,UV*vec2(2.0,0.42)).r*0.12;
    SPECULAR=0.37;
}
