import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../theme.dart';

class RecordingControls extends StatelessWidget {
  final RecordingState state; final VoidCallback onStart, onPause, onResume, onStop; final bool isDark; final bool isEditorial;
  const RecordingControls({super.key, required this.state, required this.onStart, required this.onPause, required this.onResume, required this.onStop, this.isDark=false, this.isEditorial=false});
  @override Widget build(BuildContext context){
    final bg=isEditorial?Editorial.card:(isDark?DarkPremium.card:Colors.white);
    final border=isEditorial?Editorial.border:(isDark?DarkPremium.border:GoogleColors.border);
    final div=isEditorial?Editorial.divider:(isDark?DarkPremium.divider:GoogleColors.divider);
    return Container(padding:const EdgeInsets.symmetric(horizontal:24,vertical:16), decoration:BoxDecoration(color:bg, borderRadius:const BorderRadius.vertical(top:Radius.circular(20)), border:Border(top:BorderSide(color:border)), boxShadow:[BoxShadow(color:Colors.black.withAlpha(isEditorial?12:20), blurRadius:16, offset:Offset(0,-4))]), child:SafeArea(top:false, child:Column(mainAxisSize:MainAxisSize.min, children:[
      Container(width:32,height:4, decoration:BoxDecoration(color:div, borderRadius:BorderRadius.circular(2))), const SizedBox(height:16),
      Row(mainAxisAlignment:MainAxisAlignment.center, children:_build()),
    ])));
  }
  List<Widget> _build(){
    final idleColor=isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.red);
    switch(state){
      case RecordingState.idle: return [_btn(color:idleColor, icon:Icons.fiber_manual_record, size:64, onTap:onStart)];
      case RecordingState.recording: return [_small(Icons.stop, onStop), const SizedBox(width:48), _btn(color:isEditorial?Editorial.navy:(isDark?DarkPremium.neonBlue:GoogleColors.blue), icon:Icons.pause, size:56, onTap:onPause)];
      case RecordingState.paused: return [_small(Icons.stop, onStop), const SizedBox(width:48), _btn(color:isEditorial?Editorial.sage:(isDark?DarkPremium.neonGreen:GoogleColors.green), icon:Icons.play_arrow, size:56, onTap:onResume)];
    }
  }
  Widget _btn({required Color color, required IconData icon, required double size, required VoidCallback onTap}){
    return GestureDetector(onTap:onTap, child:Container(width:size,height:size, decoration:BoxDecoration(color:color, shape:BoxShape.circle, boxShadow:[BoxShadow(color:color.withAlpha(70), blurRadius:12)]), child:Icon(icon, color:Colors.white, size:size*0.5)));
  }
  Widget _small(IconData icon, VoidCallback onTap){
    final bg=isEditorial?Editorial.paperDark:(isDark?DarkPremium.cardElevated:GoogleColors.surface);
    final border=isEditorial?Editorial.border:(isDark?DarkPremium.border:GoogleColors.border);
    final fg=isEditorial?Editorial.inkSecondary:(isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    return GestureDetector(onTap:onTap, child:Container(width:48,height:48, decoration:BoxDecoration(color:bg, shape:BoxShape.circle, border:Border.all(color:border)), child:Icon(icon, color:fg, size:22)));
  }
}
