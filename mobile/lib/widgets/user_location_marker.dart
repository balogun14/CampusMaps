import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class UserLocationMarker extends StatefulWidget {
  final double heading; final bool isNavigating; final double size; final bool isDark; final bool isEditorial;
  const UserLocationMarker({super.key, this.heading=0, this.isNavigating=false, this.size=48, this.isDark=false, this.isEditorial=false});
  @override State<UserLocationMarker> createState()=> _UserLocationMarkerState();
}
class _UserLocationMarkerState extends State<UserLocationMarker> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _pulse;
  @override void initState(){ super.initState(); _ctrl=AnimationController(vsync:this, duration:const Duration(milliseconds:1400))..repeat(reverse:true); _pulse=Tween<double>(begin:0.85,end:1.0).animate(CurvedAnimation(parent:_ctrl, curve:Curves.easeInOut)); }
  @override void dispose(){ _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    Color dot, border;
    if(widget.isEditorial){ dot=Editorial.coral; border=Editorial.card; } else if(widget.isDark){ dot=DarkPremium.neonBlue; border=DarkPremium.bg; } else { dot=GoogleColors.blue; border=Colors.white; }
    return AnimatedBuilder(animation:_pulse, builder:(context,_){
      return SizedBox(width:widget.size,height:widget.size, child:Stack(alignment:Alignment.center, children:[
        Container(width:widget.size*1.7*_pulse.value, height:widget.size*1.7*_pulse.value, decoration:BoxDecoration(shape:BoxShape.circle, color:dot.withAlpha(16))),
        Container(width:widget.size*1.15*_pulse.value, height:widget.size*1.15*_pulse.value, decoration:BoxDecoration(shape:BoxShape.circle, color:dot.withAlpha(32))),
        Transform.rotate(angle:widget.isNavigating?(widget.heading*pi/180):0, child:Container(
          width:widget.size*0.5,height:widget.size*0.5,
          decoration:BoxDecoration(shape:BoxShape.circle, color:dot, border:Border.all(color:border, width:3), boxShadow:[BoxShadow(color:dot.withAlpha(80), blurRadius:10), BoxShadow(color:Colors.black.withAlpha(50), blurRadius:6)]),
          child: widget.isNavigating? Icon(Icons.navigation, color:border, size:14): null,
        )),
      ]));
    });
  }
}
