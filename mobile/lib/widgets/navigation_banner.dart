import 'package:flutter/material.dart';
import '../models/route_response.dart';
import '../services/navigation_service.dart';
import '../theme.dart';

class NavigationBanner extends StatelessWidget {
  final NavigationUpdate update; final VoidCallback onExit; final bool isDark; final bool isEditorial;
  static const _icons={'north':Icons.arrow_upward,'south':Icons.arrow_downward,'east':Icons.arrow_forward,'west':Icons.arrow_back,'northeast':Icons.north_east,'northwest':Icons.north_west,'southeast':Icons.south_east,'southwest':Icons.south_west,'straight':Icons.arrow_upward};
  const NavigationBanner({super.key, required this.update, required this.onExit, this.isDark=false, this.isEditorial=false});
  @override Widget build(BuildContext context){
    final step=update.currentStep; final icon=_icons[step.direction]??Icons.arrow_upward;
    Color bg, fg;
    if(isEditorial){ bg=Editorial.navy; fg=Colors.white; } else if(isDark){ bg=DarkPremium.card; fg=DarkPremium.textPrimary; } else { bg= update.arrived? Colors.white: GoogleColors.green; fg= update.arrived? GoogleColors.textPrimary: Colors.white; }
    return Container(decoration:BoxDecoration(boxShadow:[BoxShadow(color:Colors.black.withAlpha(40), blurRadius:12, offset:Offset(0,4))]), child:ClipRRect(borderRadius:const BorderRadius.vertical(bottom:Radius.circular(16)), child:Container(color:bg, child:SafeArea(bottom:false, child:Column(mainAxisSize:MainAxisSize.min, children:[
      if(update.arrived) _arrival(bg, fg) else _nav(step, icon, fg),
    ])))));
  }
  Widget _arrival(Color bg, Color fg){
    return Padding(padding:const EdgeInsets.fromLTRB(16,14,12,14), child:Row(children:[
      Container(padding:const EdgeInsets.all(8), decoration:BoxDecoration(color:isEditorial?Editorial.coral:(isDark?DarkPremium.neonGreen:GoogleColors.green), shape:BoxShape.circle), child:Icon(Icons.check, color:Colors.white, size:24)),
      const SizedBox(width:12), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('You have arrived', style:TextStyle(fontSize:16, fontWeight:FontWeight.w800, color:fg, fontStyle:isEditorial?FontStyle.italic:FontStyle.normal)), Text('Welcome to MEDILAG', style:TextStyle(fontSize:13, color:isEditorial?Editorial.paperDark:(isDark?DarkPremium.textSecondary:GoogleColors.textSecondary)))])),
      IconButton(icon:Icon(Icons.close, color:isEditorial?Colors.white:(isDark?DarkPremium.textSecondary:GoogleColors.textSecondary)), onPressed:onExit),
    ]));
  }
  Widget _nav(RouteStep step, IconData icon, Color fg){
    final accent=isEditorial?Editorial.coral:(isDark?DarkPremium.neonGreen:GoogleColors.green);
    return Padding(padding:const EdgeInsets.fromLTRB(16,12,12,12), child:Column(children:[
      Row(children:[
        Container(decoration:BoxDecoration(color:isEditorial?Editorial.card:(isDark?DarkPremium.bg:Colors.white), borderRadius:BorderRadius.circular(12), border:Border.all(color:isEditorial?Editorial.border:(isDark?DarkPremium.border:GoogleColors.border))), padding:const EdgeInsets.all(8), child:Icon(icon, color:accent, size:28)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text(step.instruction.isNotEmpty?step.instruction:'Continue', style:TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:fg, fontStyle:isEditorial?FontStyle.italic:FontStyle.normal), maxLines:2),
          if(step.streetName.isNotEmpty) Text(step.streetName, style:TextStyle(fontSize:13, color:isEditorial?Editorial.paperDark:(isDark?DarkPremium.textSecondary:const Color(0xFFE8F5E9)))),
        ])),
        IconButton(icon:Icon(Icons.close, color:isEditorial?Colors.white:(isDark?DarkPremium.textSecondary:Colors.white)), onPressed:onExit),
      ]),
      const SizedBox(height:10),
      Row(children:[
        _chip(_fmtDist(update.distanceToNextTurnMeters), Icons.turn_slight_right),
        const SizedBox(width:8), _chip(_fmtDist(update.remainingDistanceMeters), Icons.straighten),
        const SizedBox(width:8), _chip(_fmtDur(update.remainingDurationSeconds), Icons.access_time),
      ]),
    ]));
  }
  Widget _chip(String t, IconData icon){
    return Expanded(child:Container(padding:const EdgeInsets.symmetric(vertical:6,horizontal:8), decoration:BoxDecoration(color:isEditorial?Editorial.paperDark:(isDark?DarkPremium.cardElevated:Colors.white.withAlpha(230)), borderRadius:BorderRadius.circular(20), border:Border.all(color:isEditorial?Editorial.border:(isDark?DarkPremium.border:Colors.transparent))), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(icon, size:14, color:isEditorial?Editorial.coral:(isDark?DarkPremium.neonGreen:GoogleColors.green)), const SizedBox(width:4), Flexible(child:Text(t, style:TextStyle(fontSize:12, color:isEditorial?Editorial.ink:(isDark?DarkPremium.textPrimary:GoogleColors.textPrimary), fontWeight:FontWeight.w700), overflow:TextOverflow.ellipsis))])));}
  String _fmtDist(double m)=> m>=1000? '${(m/1000).toStringAsFixed(1)} km':'${m.round()} m';
  String _fmtDur(double s){ final r=s.round(), m=r~/60, h=m~/60; if(h>0) return '${h}h ${m%60}m'; if(m>0) return '${m}m'; return '${r}s'; }
}
