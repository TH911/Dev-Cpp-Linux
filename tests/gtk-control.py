#!/usr/bin/env python3
"""Drive native controls observed by gtk-state-probe; never modify IDE state directly."""
import json,re,subprocess,sys,time
state_file,title,action,*values=sys.argv[1:]
# Bare Xvfb has no window manager to focus a modal on pointer clicks.
windows=subprocess.check_output(['xdotool','search','--onlyvisible','--name','^'+re.escape(title)+'$'],text=True).split()
if windows:subprocess.run(['xdotool','windowfocus',windows[0]],check=True)
def controls():
    rows=json.load(open(state_file)); roots=[x for x in rows if x['type']=='GtkWindow' and x['text']==title and x['viewable']]
    if not roots:return []
    ids={roots[0]['id']}
    while True:
        extra={x['id'] for x in rows if x['parent'] in ids}-ids
        if not extra:break
        ids.update(extra)
    return [x for x in rows if x['id'] in ids and x['viewable'] and x['visible'] and x['mapped'] and x['width']>0]
def click(w):
    subprocess.run(['xdotool','mousemove',str(w['x']+w['width']//2),str(w['y']+w['height']//2)],check=True)
    time.sleep(.08)
    subprocess.run(['xdotool','click','1'],check=True)
for attempt in range(100):
    try:
        rows=controls()
        if action in ('click','button'):
            found=[w for w in rows if w['type'] in ('GtkLabel','GtkButton','GtkCheckButton') and w['text'].replace('_','')==values[0]]
            if action=='button':
                by_id={w['id']:w for w in rows};buttons=[]
                for candidate in found:
                    while candidate and candidate['type']!='GtkButton':candidate=by_id.get(candidate['parent'])
                    if candidate:buttons.append(candidate)
                found=buttons
            if not found:raise ValueError('control not found')
            click(found[0])
        elif action=='entry':
            entries=sorted([w for w in rows if w['type'] in ('GtkEntry','GtkSpinButton') and w['sensitive']],key=lambda x:(x['y'],x['x']))
            item=entries[int(values[0])]; click(item)
            subprocess.run(['xdotool','key','--clearmodifiers','ctrl+a'],check=True)
            subprocess.run(['xdotool','type','--clearmodifiers','--delay','5','--',values[1]],check=True)
        elif action in ('memo','textview'):
            entries=sorted([w for w in rows if w['type'] in ('GtkTextView','LCLWinapiClient','GtkCustomControl') and w['sensitive'] and w['width']>120 and w['height']>120],key=lambda x:(x['y'],x['x']))
            if action=='textview':entries=sorted([w for w in rows if w['type']=='GtkTextView' and w['sensitive']],key=lambda x:(x['y'],x['x']))
            click(entries[int(values[0])]);subprocess.run(['xdotool','key','--clearmodifiers','ctrl+Home','ctrl+shift+End'],check=True)
            for n,line in enumerate(values[1].split('\n')):
                if n:subprocess.run(['xdotool','key','--clearmodifiers','Return'],check=True)
                subprocess.run(['xdotool','type','--clearmodifiers','--delay','5','--',line],check=True)
        elif action=='list':
            entries=sorted([w for w in rows if w['type']=='GtkTreeView'],key=lambda x:x['x'])
            click(entries[int(values[0])]);subprocess.run(['xdotool','key','--clearmodifiers','Home']+['Down']*int(values[1]),check=True)
        else:raise RuntimeError('unknown control operation')
        time.sleep(.2);break
    except (OSError,ValueError,IndexError):time.sleep(.08)
else:raise AssertionError('Native control missing: '+str((title,action,values)))
