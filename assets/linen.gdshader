shader_type spatial;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
    vec2 p=local_pos.xz*34.0;
    vec2 aa=fwidth(p);
    float warp=sin(p.x*6.28318)*sin(p.y*6.28318);
    float attenuation=1.0-smoothstep(0.3,1.0,max(aa.x,aa.y));
    ALBEDO=vec3(0.22,0.195,0.155)*(1.0+warp*0.025*attenuation);
    ROUGHNESS=0.96;
    SPECULAR=0.15;
}
