/* Shared Canvas renderer. No network calls; assets supplied by the host. */
(function(root){
'use strict';
const C={indigo:'#4433CC',teal:'#147D85',ink:'#20213B',amber:'#F5C56A'};
const grips={'indigo-captain':[.712,.421],'indigo-partner':[.712,.392],'teal-captain':[.756,.390],'teal-partner':[.744,.411]};
function createState(){return {phase:'lobby',position:0,target:0,time:0,impactAt:-100,impactTeam:null,impactCorrect:true,finishedAt:-100,winner:null,countdown:3,reducedMotion:false};}
function tick(s,dt){if(s.reducedMotion){s.position=s.target;return;}if(['paused','reconnecting'].includes(s.phase))return;dt=Math.max(0,Math.min(dt,.05));s.time+=dt;s.position+=(s.target-s.position)*(1-Math.exp(-dt*10));if(Math.abs(s.target-s.position)<.0001)s.position=s.target;}
function line(c,x1,y1,x2,y2,color,width){c.beginPath();c.moveTo(x1,y1);c.lineTo(x2,y2);c.strokeStyle=color;c.lineWidth=width;c.lineCap='round';c.stroke();}
function text(c,value,x,y,size,color){c.fillStyle=color;c.font='700 '+size+'px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(value,x,y);}
function player(c,images,s,key,x,flip,phase){
 const grip=grips[key],team=flip?'teal':'indigo',age=s.time-s.impactAt;
 const impulse=age>=0&&age<.65&&s.impactTeam===team&&s.impactCorrect?Math.sin(age/.65*Math.PI):0;
 const active=['playing','lobby'].includes(s.phase);
 const sway=s.reducedMotion||!active?0:Math.sin(s.time*2.6+phase)*.009+impulse*.035;
 const extent=340,dir=flip?-1:1,shadowX=x+dir*(.54-grip[0])*extent,shadowY=340+(.915-grip[1])*extent;
 c.fillStyle='rgba(32,33,59,.12)';c.beginPath();c.ellipse(shadowX,shadowY+3,97.5,6.5,0,0,Math.PI*2);c.fill();
 c.save();c.translate(x,340);c.rotate(flip?-sway:sway);c.scale(dir,1);
 c.drawImage(images[key],-grip[0]*extent,-grip[1]*extent,extent,extent);c.restore();
 if(!s.reducedMotion&&impulse>0){const p=age/.65;for(let i=0;i<8;i++){c.fillStyle='rgba(166,153,131,'+(1-p)*.45+')';c.beginPath();c.arc(shadowX-dir*(i*9+p*45),shadowY-Math.sin(p*Math.PI)*(8+i*2),2+i%3,0,Math.PI*2);c.fill();}}
}
function render(c,images,s,width=1200,height=600){
 c.save();c.scale(width/1200,height/600);c.beginPath();c.rect(0,0,1200,600);c.clip();
 const bg=images.background,sh=bg.width/2;c.drawImage(bg,0,(bg.height-sh)/2,bg.width,sh,0,0,1200,600);
 c.fillStyle='rgba(255,255,255,.06)';c.fillRect(0,0,1200,600);
 for(const x of [510,690])for(let y=365;y<550;y+=20)line(c,x,y,x,y+9,x<600?'rgba(68,51,204,.35)':'rgba(20,125,133,.35)',3);
 text(c,'INDIGO',245,64,23,C.indigo);text(c,'TEAL',955,64,23,C.teal);
 const shift=s.position*90;
 player(c,images,s,'indigo-partner',255+shift,false,1);player(c,images,s,'teal-partner',945+shift,true,1.4);
 player(c,images,s,'indigo-captain',395+shift,false,0);player(c,images,s,'teal-captain',805+shift,true,.4);
 const sag=5*(1-Math.abs(s.position));const ropeY=x=>340+Math.sin((x-190-shift)/820*Math.PI)*sag;
 for(const [color,w] of [['#79613D',10],['#E9D2A2',6]]){c.beginPath();c.moveTo(190+shift,340);for(let x=194+shift;x<=1010+shift;x+=4)c.lineTo(x,ropeY(x));c.strokeStyle=color;c.lineWidth=w;c.lineCap='round';c.stroke();}
 for(let x=194+shift;x<1008+shift;x+=10)line(c,x-2,ropeY(x)-2.5,x+2,ropeY(x)+2.5,'#AD8E59',1.3);
 const center=600+shift;c.beginPath();c.moveTo(center-8,ropeY(center)-5);c.lineTo(center+8,ropeY(center)-5);c.lineTo(center+12,382);c.lineTo(center,374);c.lineTo(center-12,382);c.closePath();c.fillStyle=C.amber;c.fill();
 const age=s.time-s.impactAt;
 if(!s.reducedMotion&&age>=0&&age<.65&&s.impactTeam){const x=(s.impactTeam==='indigo'?395:805)+shift;c.save();c.globalAlpha=(1-age/.65)*.65;c.strokeStyle=s.impactCorrect?C[s.impactTeam]:'#B42332';c.lineWidth=3;c.beginPath();c.arc(x,340,18+age*65,0,Math.PI*2);c.stroke();c.restore();}
 if(s.phase==='lobby')text(c,'Ready to pull together?',600,140,28,C.ink);
 if(s.phase==='countdown'){c.fillStyle='rgba(32,33,59,.24)';c.fillRect(0,0,1200,600);text(c,String(s.countdown),600,205,100,'white');}
 if(['paused','reconnecting'].includes(s.phase)){c.fillStyle='rgba(255,255,255,.55)';c.fillRect(0,0,1200,600);text(c,s.phase==='paused'?'Paused':'Reconnecting…',600,230,40,C.ink);}
 if(s.phase==='finished'){
 text(c,s.winner?(s.winner==='indigo'?'Indigo':'Teal')+' wins the round':'A well-matched round. Draw.',600,140,38,C.ink);
 const a=s.time-s.finishedAt;if(!s.reducedMotion&&s.winner&&a>=0&&a<2.2){const t=a/2.2;for(let i=0;i<48;i++){const x=80+(i*137)%1040+Math.sin(t*7+i)*25,y=-50+t*650-(i%7)*23;c.save();c.translate(x,y);c.rotate(t*8+i);c.globalAlpha=1-t*.6;c.fillStyle=[C[s.winner],C.amber,'#FFFFFF'][i%3];c.fillRect(-3,-6,6,12);c.restore();}}
 }
 c.restore();
}
const api={C,grips,createState,tick,render};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.RopeKit=api;
})(typeof globalThis!=='undefined'?globalThis:this);
