shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float board_size = 19.0;
uniform float span = 6.5;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex(){
    local_pos=VERTEX;
    local_normal=NORMAL;
}
void fragment(){
    float top=smoothstep(0.8,0.98,local_normal.y);
    vec2 uv=vec2(local_pos.x*0.20,local_pos.z*0.08)+vec2(0.21,0.17);
    if(top<0.5){uv=vec2((local_pos.x+local_pos.z)*0.20,local_pos.y*0.55)+vec2(0.21,0.17);}
    vec3 scan=texture(grain,uv).rgb;
    float v=dot(scan,vec3(0.299,0.587,0.114));
    // The scan provides irregular fine fibre; the long axial grain reads as planed timber.
    float wave=local_pos.x*155.0+sin(local_pos.z*0.6+local_pos.x*4.0)*0.65+sin(local_pos.x*3.4)*1.2;
    float fibre=pow(0.5+0.5*sin(wave),6.0);
    float grain_value=clamp((v-0.025)*8.0,0.0,1.0);
    vec3 base=mix(vec3(0.46,0.30,0.145),vec3(0.64,0.455,0.24),0.45+grain_value*0.50);
    base*=1.015-fibre*0.10;
    float pitch=span/(board_size-1.0);
    vec2 grid_pos=vec2(local_pos.x+span*0.5,local_pos.z/1.04+span*0.5);
    vec2 g=grid_pos/pitch;
    vec2 distance_to_line=abs(fract(g+0.5)-0.5)*pitch;
    vec2 aa=max(fwidth(grid_pos),vec2(0.0001));
    // Analytic pixel coverage keeps fine ink continuous at grazing angles.
    vec2 line_mask=clamp((vec2(0.009)+aa*0.5-distance_to_line)/aa,vec2(0.0),vec2(1.0));
    float inside=step(-0.006,grid_pos.x)*step(grid_pos.x,span+0.006)*step(-0.006,grid_pos.y)*step(grid_pos.y,span+0.006);
    float ink=max(line_mask.x,line_mask.y)*inside;
    float first=board_size>10.0?3.0:2.0;
    float middle=(board_size-1.0)*0.5;
    float last=board_size-1.0-first;
    for(int i=0;i<3;i++){
        for(int j=0;j<3;j++){
            if(board_size<19.0 && ((i==1)!=(j==1)))continue;
            vec2 star=vec2(i==0?first:(i==1?middle:last),j==0?first:(j==1?middle:last));
            float d=length((g-star)*pitch);
            ink=max(ink,1.0-smoothstep(0.027-aa.x,0.027+aa.x,d));
        }
    }
    // Inlaid ink is part of the surface, with no raised grid-bar geometry.
    ALBEDO=mix(base,vec3(0.035,0.023,0.012),ink*top*0.94);
    ROUGHNESS=0.5+(grain_value-0.5)*0.045;
    SPECULAR=0.3;
    NORMAL_MAP=texture(normal_tex,uv).rgb;
    NORMAL_MAP_DEPTH=0.06;
}
