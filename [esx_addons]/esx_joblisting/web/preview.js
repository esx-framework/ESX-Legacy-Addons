// Figma fixture, only enabled explicitly in a standalone browser: ?preview=1.
if (typeof GetParentResourceName !== 'function' && new URLSearchParams(location.search).has('preview')) {
  const tasks = Array.from({length:6}, () => ({title:'Get 40 diamonds',description:'Lorem ipsum dolor sit amet, consectetur.',current:36,target:40}));
  const description = 'Being a miner is tough work, but it pays well. Your job is to extract raw materials from the mine located outside the city.\n\nUse your pickaxe to break rocks and collect valuable resources such as iron, coal, or diamonds.\nOnce you’ve gathered enough materials, head to the refinery or sell point to exchange them for cash.\n\nThe job requires endurance and strength, but every run can bring a solid income.\nHard work underground — clean profit above.\n\nHard work underground - clean prrofit above.';
  const jobs = Array.from({length:9}, (_,i) => ({name:`miner${i}`,label:'Miner',subtitle:'Lorem ipsum',description,image:'assets/miner.png',rating:4,salary:5200,requirement:'Driver’s License',location:{x:2954,y:2787},tasks}));
  window.postMessage({action:'open',preview:true,jobs,profile:{name:'Firstname Lastname',id:12,age:25,gender:'Male',phone:'000 000 000',job:{name:'miner',label:'Miner',salary:5400,gradeLabel:'Senior Miner'},stats:{earnings:150400,minutes:872,days:8,extra:Array.from({length:3},()=>({label:'Lorem ipsum',value:'Lorem ipsum'}))},tasks}},'*');
  if (new URLSearchParams(location.search).has('hud')) {
    window.postMessage({action:'tasks',visible:true,grade:'Grade Job',tasks:tasks.map(t=>({...t,current:20}))},'*');
    window.postMessage({action:'taskProgress',task:{title:'Tittle Task',current:40,target:50}},'*');
  }
}
