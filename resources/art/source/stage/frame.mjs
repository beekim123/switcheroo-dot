/** Original D0 proscenium. Integer geometry only; no external images. */
const stars = [[101,64],[188,86],[225,52],[442,66],[543,80],[84,144],[173,167],[459,169],[554,182],[389,172],[256,181],[120,194],[514,207]];
const slotCenters = [144,232,320,408,496];
function diamond(g,x,y,r,color) { g.polygon([[x,y-r],[x+r,y],[x,y+r],[x-r,y]],color); }
function curtain(g,mirror) {
  const X=x=>mirror?639-x:x;
  const poly=(points,color)=>g.polygon(points.map(([x,y])=>[X(x),y]),color);
  poly([[29,20],[101,25],[96,70],[86,114],[70,157],[49,188],[47,239],[30,255]],'ink');
  poly([[31,21],[97,25],[92,70],[82,113],[66,155],[45,186],[44,238],[32,249]],'velvet0');
  poly([[33,23],[54,26],[58,88],[52,139],[43,175],[40,239],[33,244]],'velvet1');
  poly([[54,24],[78,27],[74,91],[64,137],[51,174],[45,187],[53,143],[59,92]],'velvet2');
  poly([[73,28],[92,29],[88,70],[77,111],[64,144],[55,155],[65,120],[74,78]],'velvet1');
  poly([[57,31],[64,31],[64,77],[58,119],[51,143],[56,112],[60,74]],'velvet3');
  poly([[84,32],[89,33],[83,75],[74,101],[79,73]],'velvet2');
  const edge=[[97,25],[92,70],[82,113],[66,155],[45,186],[44,238]];
  for(let i=0;i<edge.length-1;i++){g.line(X(edge[i][0]),edge[i][1],X(edge[i+1][0]),edge[i+1][1],'gold0');g.line(X(edge[i][0]-2),edge[i][1],X(edge[i+1][0]-2),edge[i+1][1],'gold2');}
  poly([[34,176],[48,174],[51,181],[45,185],[33,183]],'gold0');
  g.line(X(34),177,X(48),176,'gold3');g.line(X(34),180,X(48),179,'gold1');
  g.line(X(48),182,X(57),193,'gold2');g.line(X(57),193,X(57),208,'gold1');
  g.rect(mirror?579:54,205,7,9,'gold0');g.line(X(55),206,X(55),212,'gold2');g.line(X(58),207,X(58),214,'gold1');
}
export const assets = [{
  meta:{id:'stage.frame',category:'stage',size:[640,360],anchor:[0,0],frames:1,animations:{}},
  draw(g) {
    g.fill('night0');
    // Flat, quiet painted backdrop. The central title zone has no painted words.
    g.rect(40,44,560,166,'night1');
    g.rect(40,202,560,32,'night0');
    for(const [x,y] of stars){g.px(x,y,'silver0');if(x%3===0)g.px(x+1,y,'silver0');}
    for(const [x,y] of [[195,151],[453,93],[532,166]]) {g.line(x-2,y,x+2,y,'night2');g.line(x,y-2,x,y+2,'night2');g.px(x,y,'silver1');}
    // Twin moons: warm crescent and a smaller cool full moon.
    g.ellipse(102,84,48,48,'gold0');g.ellipse(104,84,44,44,'gold2');g.ellipse(110,84,38,36,'gold3');
    g.ellipse(119,80,36,38,'night1');
    g.ellipse(491,111,36,36,'silver0');g.ellipse(492,111,33,33,'silver1');g.ellipse(494,111,28,29,'silver2');
    g.rect(500,117,5,3,'silver1');g.rect(514,124,4,5,'silver1');g.rect(499,131,3,2,'silver1');
    // Layered low-saturation scenery below the character/intent zone.
    g.polygon([[50,223],[91,208],[128,215],[181,201],[217,212],[258,199],[303,216],[351,202],[387,211],[433,196],[470,207],[524,201],[590,221],[590,237],[50,237]],'night2');
    g.polygon([[50,232],[99,217],[151,227],[207,215],[271,228],[319,218],[383,232],[440,215],[501,224],[560,215],[590,227],[590,239],[50,239]],'night0');
    // Proscenium wooden columns, inset gold rails, squared corner joinery.
    for(const x of [16,605]) {
      g.rect(x,16,19,253,'ink');g.rect(x+2,18,15,248,'stage0');g.rect(x+4,18,4,248,'stage2');g.rect(x+5,19,1,245,'stage3');g.rect(x+13,20,2,244,'gold0');
      for(const y of [29,56,224,250]){g.rect(x-4,y,27,5,'ink');g.rect(x-3,y,25,2,'gold1');g.line(x-2,y,x+20,y,'gold2');}
      diamond(g,x+10,143,6,'gold0');diamond(g,x+10,142,3,'gold2');
    }
    curtain(g,false);curtain(g,true);
    // Seven scalloped velvet valances; top-left grouped highlights.
    g.rect(24,9,592,24,'ink');g.rect(26,11,588,19,'velvet0');
    for(let i=0;i<7;i++) {
      const x=28+i*83;
      g.polygon([[x,18],[x+83,18],[x+79,37],[x+64,48],[x+42,55],[x+20,48],[x+5,37]],'ink');
      g.polygon([[x+2,19],[x+81,19],[x+77,36],[x+63,46],[x+42,52],[x+21,46],[x+7,36]],'velvet1');
      g.polygon([[x+8,20],[x+75,20],[x+65,31],[x+42,41],[x+20,33]],'velvet2');
      g.line(x+12,23,x+35,33,'velvet3');g.line(x+35,33,x+49,32,'velvet3');
      for(const [a,b] of [[[x+7,37],[x+21,47]],[[x+21,47],[x+42,53]],[[x+42,53],[x+63,47]],[[x+63,47],[x+78,37]]])g.line(...a,...b,'gold2');
      g.line(x+42,54,x+42,59,'gold0');g.rect(x+40,58,5,4,'gold1');g.px(x+41,58,'gold3');
    }
    g.rect(18,5,604,8,'ink');g.rect(20,7,600,3,'gold1');g.line(21,7,618,7,'gold3');g.line(24,12,615,12,'gold0');
    // Top-center paired moon crest, small enough not to compete with the title.
    diamond(g,320,16,13,'ink');diamond(g,320,16,10,'gold1');diamond(g,320,16,7,'gold2');g.px(317,13,'gold3');g.px(323,18,'gold0');
    // Stage floor, restrained plank seams and short wood-grain marks.
    g.rect(32,235,576,45,'ink');g.rect(35,237,570,41,'stage1');g.line(36,238,603,238,'stage3');
    for(const y of [244,255,268])g.line(36,y,603,y,'stage0');
    for(const [y,offset] of [[239,0],[245,45],[256,10],[269,67]])for(let x=63+offset;x<602;x+=109)g.line(x,y,x+(y-238),Math.min(277,y+8),'stage0');
    for(let i=0;i<34;i++){const x=43+(i*53)%550,y=241+(i*13)%34;g.line(x,y,x+7+i%6,y,i%3?'stage2':'stage0');}
    // Five unmistakable standing positions, with generous space between them.
    for(const x of slotCenters) {
      g.ellipse(x-36,248,72,17,'stage0');g.ellipse(x-34,248,68,15,'gold0');g.ellipse(x-31,249,62,12,'stage2');g.ellipse(x-28,250,56,8,'stage1');
      g.line(x-14,261,x+14,261,'gold2');g.line(x-10,262,x+10,262,'gold0');
      diamond(g,x,263,2,'gold1');
    }
    // Front fascia. Center below y302 stays dark and quiet for runtime UI.
    g.rect(24,278,592,82,'ink');g.rect(28,280,584,77,'stage0');g.rect(29,280,582,4,'stage2');g.line(31,280,609,280,'stage3');g.line(31,284,609,284,'gold0');
    g.rect(111,299,418,50,'ink');g.line(113,299,526,299,'gold0');g.line(113,349,526,349,'stage1');
    for(const x of [39,550]) {g.rect(x,303,51,35,'ink');g.rect(x+2,305,47,31,'stage1');g.rect(x+5,308,41,25,'stage0');diamond(g,x+25,320,8,'gold0');diamond(g,x+25,320,4,'gold1');}
    // Nine small, hard-edged pools of light. No semi-transparent glow.
    for(let x=72;x<=568;x+=62) {
      g.ellipse(x-13,275,27,7,'gold0');g.ellipse(x-9,276,19,5,'lamp0');
      g.rect(x-7,280,15,12,'ink');g.rect(x-5,280,11,7,'gold0');g.rect(x-4,279,9,5,'lamp1');g.rect(x-3,278,7,4,'lamp2');g.rect(x-2,278,4,2,'lamp3');g.rect(x-8,292,17,3,'ink');g.line(x-5,291,x+5,291,'gold1');
    }
    // Audience silhouettes only at the lower corners, not behind controls.
    for(const [x,y,r] of [[3,337,9],[25,344,8],[50,344,10],[75,349,8],[563,349,8],[587,344,10],[615,341,8],[637,336,9]]) {
      g.ellipse(x-r,y-r,r*2,r*2,'ink');g.ellipse(x-r-5,y+4,r*2+10,28,'ink');
      g.line(x-r+2,y-r+2,x-r+5,y-r+1,'ink2');
    }
  },
}];
