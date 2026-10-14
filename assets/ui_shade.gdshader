shader_type canvas_item;
render_mode unshaded;
uniform float learning_focus = 0.0;
void fragment(){
    float right=smoothstep(0.64,0.87,UV.x)*0.65;
    float top=(1.0-smoothstep(0.0,0.23,UV.y))*0.48;
    top=max(top,(1.0-smoothstep(0.09,0.30,UV.y))*0.64*learning_focus);
    float bottom=smoothstep(0.78,1.0,UV.y)*0.44;
    float left=(1.0-smoothstep(0.0,0.20,UV.x))*0.07;
    COLOR=vec4(vec3(0.055,0.045,0.030),max(max(right,top),max(bottom,left)));
}
