import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../theme.dart';

class RecordingStatsCard extends StatelessWidget {
  final RecordingStats stats; final bool isDark; final bool isEditorial;
  const RecordingStatsCard({super.key, required this.stats, this.isDark=false, this.isEditorial=false});
  @override Widget build(BuildContext context){
    final d=stats.elapsed; final h=d.inHours, m=d.inMinutes.remainder(60), s=d.inSeconds.remainder(60);
    final timeStr=h>0?'$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}':'$m:${s.toString().padLeft(2,'0')}';
    final distStr=stats.distanceMeters>=1000?'${(stats.distanceMeters/1000).toStringAsFixed(2)} km':'${stats.distanceMeters.toStringAsFixed(0)} m';
    final bg=isEditorial?Editorial.card:(isDark?DarkPremium.card:Colors.white); final border=isEditorial?Editorial.border:(isDark?DarkPremium.border:GoogleColors.border);
    final div=isEditorial?Editorial.divider:(isDark?DarkPremium.divider:GoogleColors.divider);
    return Container(margin:const EdgeInsets.symmetric(horizontal:16), padding:const EdgeInsets.symmetric(horizontal:16,vertical:14), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(16), border:Border.all(color:border), boxShadow:[BoxShadow(color:Colors.black.withAlpha(isEditorial?10:12), blurRadius:12, offset:Offset(0,4))]), child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround, children:[
      _item(Icons.timer_outlined, timeStr, 'Time', isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue)),
      Container(width:1,height:40, color:div),
      _item(Icons.straighten, distStr, 'Distance', isEditorial?Editorial.sage:(isDark?DarkPremium.neonGreen:GoogleColors.green)),
      Container(width:1,height:40, color:div),
      _item(Icons.speed, stats.currentPaceMinPerKm!=null?'${stats.currentPaceMinPerKm!.floor()}:${((stats.currentPaceMinPerKm!-stats.currentPaceMinPerKm!.floor())*60).round().toString().padLeft(2,'0')}':'--:--', 'Pace', isEditorial?Editorial.terracotta:(isDark?DarkPremium.neonYellow:GoogleColors.red)),
    ]));
  }
  Widget _item(IconData icon, String v, String label, Color c){
    final txt=isEditorial?Editorial.ink:(isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=isEditorial?Editorial.inkSecondary:(isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    return Column(mainAxisSize:MainAxisSize.min, children:[Icon(icon, size:18, color:c), const SizedBox(height:4), Text(v, style:TextStyle(fontWeight:FontWeight.w800, fontSize:15, color:txt, fontStyle:isEditorial?FontStyle.italic:FontStyle.normal)), Text(label, style:TextStyle(fontSize:11, color:sub))]);
  }
}
