'use strict';
(async()=>{
 const root='../assets/rope_pull/',state=RopeKit.createState(),images={},canvas=document.getElementById('arena'),ctx=canvas.getContext('2d');
 const $=id=>document.getElementById(id),teams=['indigo','teal'];
 const samples={indigo:[[10,5,'×'],[8,7,'+'],[9,4,'×'],[42,6,'÷'],[17,8,'+'],[12,3,'×'],[81,9,'÷'],[25,16,'+']],teal:[[7,6,'×'],[16,9,'+'],[8,8,'×'],[63,7,'÷'],[23,19,'+'],[11,4,'×'],[72,8,'÷'],[35,14,'+']]};
 const index={indigo:0,teal:0},scores={indigo:0,teal:0};let remaining=60,countdown=3,deadline=0,interval=null,lastFrame=0,raf=0,ready=false;
 const media=matchMedia('(prefers-reduced-motion: reduce)');$('reduce').checked=media.matches;state.reducedMotion=media.matches;
 function cue(name){if(!$('sound').checked)return;const a=new Audio(root+'audio/'+name+'.wav');a.volume=.3;a.play().catch(()=>{});}
 function answer(q){return q[2]==='×'?q[0]*q[1]:q[2]==='÷'?q[0]/q[1]:q[0]+q[1];}
 function question(team){return samples[team][index[team]%samples[team].length];}
 function setQuestion(team){const q=question(team);$(team+'-question').textContent=q[0]+' '+q[2]+' '+q[1]+' = ?';$(team+'-answer').value='';}
 function update(){
  const seconds=Math.ceil(remaining);$('clock').textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');$('phase').textContent=state.phase==='playing'?'Round in progress':state.phase[0].toUpperCase()+state.phase.slice(1);
  teams.forEach(t=>{$(t+'-score').textContent=scores[t];$(t+'-answer').disabled=state.phase!=='playing';$(t+'-form').querySelectorAll('button').forEach(b=>b.disabled=state.phase!=='playing');});
  $('pause').disabled=!['playing','paused'].includes(state.phase);$('pause').textContent=state.phase==='paused'?'Resume':'Pause';
  $('start').disabled=!ready||['playing','paused','countdown'].includes(state.phase);$('start').textContent=state.phase==='finished'?'Play again':'Start round';
  const lead=scores.indigo===scores.teal?'The teams are level.':(scores.indigo>scores.teal?'Indigo':'Teal')+' is ahead.';$('lead').textContent=state.phase==='lobby'?'Pull the centre ribbon to your goal.':lead;
  canvas.setAttribute('aria-label','Indigo '+scores.indigo+', Teal '+scores.teal+'. '+state.phase+'. '+lead);
 }
 function render(){const dpr=Math.min(devicePixelRatio||1,2),w=Math.max(1,canvas.clientWidth),h=w/2;if(canvas.width!==Math.round(w*dpr)){canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr);}ctx.setTransform(1,0,0,1,0,0);RopeKit.render(ctx,images,state,canvas.width,canvas.height);$('meter-marker').style.left=(50+state.position*42)+'%';}
 function frame(now){raf=0;if(!ready||document.hidden)return;const dt=lastFrame?(now-lastFrame)/1000:0;lastFrame=now;RopeKit.tick(state,dt);render();if(!state.reducedMotion&&!['paused','reconnecting'].includes(state.phase)&&(state.phase!=='finished'||state.time-state.finishedAt<2.3||Math.abs(state.target-state.position)>.001))raf=requestAnimationFrame(frame);}
 function animate(){if(!ready)return;if(state.reducedMotion)state.position=state.target;render();if(!raf){lastFrame=0;raf=requestAnimationFrame(frame);}}
 function finish(){clearInterval(interval);interval=null;state.phase='finished';state.winner=scores.indigo===scores.teal?null:(scores.indigo>scores.teal?'indigo':'teal');state.finishedAt=state.time;$('status').textContent=state.winner?(state.winner==='indigo'?'Indigo':'Teal')+' wins. Well played, both teams.':'Draw. A well-matched round.';if(state.winner)cue('win');update();animate();}
 function startClock(){deadline=performance.now()+remaining*1000;interval=setInterval(()=>{if(state.phase!=='playing')return;remaining=Math.max(0,(deadline-performance.now())/1000);update();if(remaining<=0)finish();},100);}
 function start(){if(!ready||!['lobby','finished'].includes(state.phase))return;clearInterval(interval);scores.indigo=0;scores.teal=0;index.indigo=0;index.teal=0;Object.assign(state,RopeKit.createState(),{reducedMotion:$('reduce').checked,phase:'countdown'});remaining=60;countdown=3;state.countdown=3;teams.forEach(t=>{setQuestion(t);$(t+'-feedback').textContent='Get ready.';$(t+'-feedback').className='feedback';});$('status').textContent='Get ready. Both teams begin together.';cue('countdown');update();animate();interval=setInterval(()=>{countdown--;if(countdown<=0){clearInterval(interval);state.phase='playing';$('status').textContent='Answer correctly to pull. Six net pulls win the demo round.';teams.forEach(t=>{$(t+'-feedback').textContent='Your turn.';});cue('start');startClock();}else{state.countdown=countdown;cue('countdown');}update();animate();},1000);}
 for(const team of teams){
  const pad=$(team+'-form').querySelector('.keypad');for(const k of ['1','2','3','4','5','6','7','8','9','Clear','0','⌫']){const b=document.createElement('button');b.type='button';b.textContent=k;b.disabled=true;b.setAttribute('aria-label',k==='⌫'?'Delete last digit':k);b.addEventListener('click',()=>{const input=$(team+'-answer');if(k==='Clear')input.value='';else if(k==='⌫')input.value=input.value.slice(0,-1);else if(input.value.length<8)input.value+=k;input.focus();});pad.appendChild(b);}
  $(team+'-form').addEventListener('submit',e=>{e.preventDefault();if(state.phase!=='playing')return;const input=$(team+'-answer'),raw=input.value.trim();if(!/^-?\d+$/.test(raw)){ $(team+'-feedback').textContent='Enter a whole-number answer.';$(team+'-feedback').className='feedback bad';return;}
   const correct=Number(raw)===answer(question(team));state.impactAt=state.time;state.impactTeam=team;state.impactCorrect=correct;cue(correct?'correct':'incorrect');
   $(team+'-feedback').textContent=correct?'✓ Correct. Your team pulls ahead.':'Not quite. Try this question again.';$(team+'-feedback').className='feedback '+(correct?'good':'bad');
   if(correct){scores[team]++;index[team]++;setQuestion(team);state.target=Math.max(-1,Math.min(1,(scores.teal-scores.indigo)/6));if(Math.abs(state.target)>=1){finish();return;}}else input.select();update();animate();
  });
 }
 $('start').addEventListener('click',start);
 $('pause').addEventListener('click',()=>{if(state.phase==='playing'){remaining=Math.max(0,(deadline-performance.now())/1000);clearInterval(interval);interval=null;state.phase='paused';$('status').textContent='Round paused.';}else if(state.phase==='paused'){state.phase='playing';$('status').textContent='Round resumed.';startClock();}update();animate();});
 $('reduce').addEventListener('change',()=>{state.reducedMotion=$('reduce').checked;animate();});$('sound').addEventListener('change',()=>{if($('sound').checked)cue('start');});
 document.addEventListener('visibilitychange',()=>{if(document.hidden){if(raf)cancelAnimationFrame(raf);raf=0;lastFrame=0;if(state.phase==='playing')$('pause').click();}else animate();});
 new ResizeObserver(()=>{if(ready)render();}).observe(canvas);
 try{const files={background:'environment/campus-court.png','indigo-captain':'characters/indigo-captain.png','indigo-partner':'characters/indigo-partner.png','teal-captain':'characters/teal-captain.png','teal-partner':'characters/teal-partner.png'};await Promise.all(Object.entries(files).map(([key,path])=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{images[key]=im;resolve();};im.onerror=()=>reject(new Error(path));im.src=root+path;})));ready=true;$('status').textContent='Ready. Choose Start round. Sound is off until you enable it.';update();animate();}catch(e){$('status').textContent='Could not load '+e.message+'. Keep the preview folder beside the assets folder and reload.';$('start').textContent='Assets unavailable';}
})();
