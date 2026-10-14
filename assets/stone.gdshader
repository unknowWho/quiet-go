shader_type spatial;
uniform bool black = false;
uniform float variation = 0.0;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment() {
    float line=sin((local_pos.x+local_pos.z*0.27)*450.0+sin(local_pos.z*23.0)*0.7+variation);
    float aa=fwidth((local_pos.x+local_pos.z*0.27)*450.0);
    float fine=line*(1.0-smoothstep(1.0,4.0,aa));
    float cloud=sin(local_pos.x*31.0+variation)*sin(local_pos.z*24.0);
    if(black){
        ALBEDO=vec3(0.010,0.011,0.012)*(1.0+cloud*0.018);
        ROUGHNESS=0.33+cloud*0.015;
        SPECULAR=0.39;
    }else{
        ALBEDO=vec3(0.62,0.615,0.585)*(1.0+fine*0.014+cloud*0.002);
        ROUGHNESS=0.29+fine*0.008;
        SPECULAR=0.38;
    }
}
