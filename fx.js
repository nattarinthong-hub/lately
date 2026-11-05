(()=>{const s=document.createElement('div');s.id='sky';document.body.prepend(s);
for(let i=0;i<70;i++){const d=document.createElement('i');d.className='st';d.style.cssText=`left:${Math.random()*100}%;top:${Math.random()*100}%;animation-delay:${Math.random()*3}s;opacity:${.3+Math.random()*.7}`;s.append(d)}
for(let i=0;i<9;i++){const d=document.createElement('i');d.className='ht';d.textContent='♥';d.style.cssText=`left:${Math.random()*100}%;font-size:${10+Math.random()*16}px;animation-duration:${12+Math.random()*10}s;animation-delay:${Math.random()*12}s`;s.append(d)}})();
