import 'package:flutter/material.dart';
import '../models/route_response.dart';
import '../theme.dart';

class DirectionsPanel extends StatelessWidget {
  final RouteResponse response; final VoidCallback onDismiss; final VoidCallback? onStartNav; final ValueChanged<RouteStep>? onStepTap; final int? selectedStepIndex; final bool isDark; final bool isEditorial;
  static const _icons={'north':Icons.arrow_upward,'south':Icons.arrow_downward,'east':Icons.arrow_forward,'west':Icons.arrow_back,'northeast':Icons.north_east,'northwest':Icons.north_west,'southeast':Icons.south_east,'southwest':Icons.south_west,'straight':Icons.arrow_upward};
  const DirectionsPanel({super.key, required this.response, required this.onDismiss, this.onStartNav, this.onStepTap, this.selectedStepIndex, this.isDark=false, this.isEditorial=false});
  @override Widget build(BuildContext context){
    final s=response.summary;
    Color bg, txt, sub, ter, border, div, surf, accent;
    if(isEditorial){ bg=Editorial.card; txt=Editorial.ink; sub=Editorial.inkSecondary; ter=Editorial.inkTertiary; border=Editorial.border; div=Editorial.divider; surf=Editorial.paperDark; accent=Editorial.coral; }
    else if(isDark){ bg=DarkPremium.card; txt=DarkPremium.textPrimary; sub=DarkPremium.textSecondary; ter=DarkPremium.textTertiary; border=DarkPremium.border; div=DarkPremium.divider; surf=DarkPremium.cardElevated; accent=DarkPremium.neonBlue; }
    else { bg=Colors.white; txt=GoogleColors.textPrimary; sub=GoogleColors.textSecondary; ter=GoogleColors.textTertiary; border=GoogleColors.border; div=GoogleColors.divider; surf=GoogleColors.surface; accent=GoogleColors.blue; }
    return Container(
      decoration:BoxDecoration(color:bg, borderRadius:const BorderRadius.vertical(top:Radius.circular(20)), border:Border(top:BorderSide(color:border)), boxShadow:[BoxShadow(color:Colors.black.withAlpha(isEditorial?18:30), blurRadius:16, offset:Offset(0,-4))]),
      constraints:BoxConstraints(maxHeight:MediaQuery.of(context).size.height*0.52),
      child:Column(mainAxisSize:MainAxisSize.min, children:[
        Container(margin:const EdgeInsets.only(top:8), width:32,height:4, decoration:BoxDecoration(color:div, borderRadius:BorderRadius.circular(2))),
        Padding(padding:const EdgeInsets.fromLTRB(16,12,16,8), child:Row(children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration:BoxDecoration(color:accent, borderRadius:BorderRadius.circular(20), boxShadow:[BoxShadow(color:accent.withAlpha(50), blurRadius:8)]), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(isEditorial?Icons.auto_stories:Icons.directions_walk, size:16, color:Colors.white), const SizedBox(width:6), Text(s.durationFormatted, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.w700, fontSize:14, fontStyle:FontStyle.italic))])),
          const SizedBox(width:8), Text('${s.distanceKm.toStringAsFixed(2)} km', style:TextStyle(color:txt, fontWeight:FontWeight.w700, fontSize:14)),
          const SizedBox(width:6), Text('·', style:TextStyle(color:sub)), const SizedBox(width:6), Text('Wander', style:TextStyle(color:sub, fontSize:12, fontStyle:FontStyle.italic)),
          const Spacer(), IconButton(onPressed:onDismiss, icon:Icon(Icons.close, size:20, color:sub), style:IconButton.styleFrom(backgroundColor:surf)),
        ])),
        if(onStartNav!=null) Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12), child:SizedBox(width:double.infinity, child:FilledButton.icon(onPressed:onStartNav, icon:const Icon(Icons.near_me, size:18), label:const Text('Wander this way'), style:FilmedStyle.call(isDark:isDark, isEditorial:isEditorial)))),
        Divider(height:1, color:div),
        Flexible(child:ListView.separated(shrinkWrap:true, padding:const EdgeInsets.symmetric(horizontal:16,vertical:8), itemCount:response.steps.length, separatorBuilder:(_,__)=>Divider(height:1, indent:48, color:div), itemBuilder:(context,i){
          final step=response.steps[i]; final icon=_icons[step.direction]??Icons.arrow_upward; final isCampus=step.isCustomPath; final isSel=selectedStepIndex==i;
          Color pinBg, pinFg, pinBorder;
          if(isSel){ pinBg=accent; pinFg=Colors.white; pinBorder=accent; } else if(isCampus){ pinBg=isEditorial?Editorial.mustard.withAlpha(30):(isDark?DarkPremium.neonYellow.withAlpha(30):GoogleColors.yellow.withAlpha(40)); pinFg=isEditorial?Editorial.navy:(isDark?DarkPremium.neonYellow:const Color(0xFF7A4A00)); pinBorder=isEditorial?Editorial.mustard:(isDark?DarkPremium.neonYellow:GoogleColors.yellow); } else { pinBg=surf; pinFg=sub; pinBorder=border; }
          return InkWell(onTap: onStepTap==null?null:()=>onStepTap!(step), borderRadius:BorderRadius.circular(12), child:Container(padding:const EdgeInsets.symmetric(vertical:10,horizontal:4), decoration:isSel?BoxDecoration(color:accent.withAlpha(isEditorial?18:18), borderRadius:BorderRadius.circular(12), border:Border.all(color:accent.withAlpha(60))):null, child:Row(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Container(width:32,height:32, decoration:BoxDecoration(color:pinBg, shape:BoxShape.circle, border:Border.all(color:pinBorder)), child:Icon(icon, size:16, color:pinFg)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[if(isCampus) Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2), margin:const EdgeInsets.only(right:6), decoration:BoxDecoration(color:isEditorial?Editorial.mustard: (isDark?DarkPremium.neonYellow:GoogleColors.yellow), borderRadius:BorderRadius.circular(4)), child:Text('CAMPUS', style:TextStyle(fontSize:9, fontWeight:FontWeight.w900, color:isEditorial?Editorial.navy:(isDark?DarkPremium.bg:const Color(0xFF7A4A00))))), Expanded(child:Text(step.instruction, style:TextStyle(fontSize:13, fontWeight:FontWeight.w500, color:txt, fontStyle:isEditorial?FontStyle.italic:FontStyle.normal), maxLines:2)), if(onStepTap!=null) Icon(Icons.chevron_right, size:16, color:ter)]),
              const SizedBox(height:2), Text(step.streetName.isNotEmpty?step.streetName:step.direction, style:TextStyle(fontSize:12, color:sub)),
              const SizedBox(height:2), Row(children:[Text('${step.distanceMeters.toStringAsFixed(0)} m · ${(step.durationSeconds/60).toStringAsFixed(0)} min', style:TextStyle(fontSize:11, color:ter)), const Spacer(), if(onStepTap!=null) Row(mainAxisSize:MainAxisSize.min, children:[Icon(Icons.streetview, size:12, color:accent), const SizedBox(width:2), Text('Peek', style:TextStyle(fontSize:11, color:accent, fontWeight:FontWeight.w700))])]),
            ])),
          ])));
        })),
      ]),
    );
  }
}
class FilmedStyle {
  static ButtonStyle call({bool isDark=false, bool isEditorial=false}){
    final bg=isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue);
    return FilledButton.styleFrom(backgroundColor:bg, foregroundColor:Colors.white, padding:const EdgeInsets.symmetric(vertical:12), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)));
  }
}
