snowmanHeight = 100;
bottomDia = snowmanHeight/2.3;
middleDia = snowmanHeight/3;
topDia = snowmanHeight - middleDia - bottomDia;
// bottom sphere Z is half of its diameter
bottomZ = bottomDia/2;
// middle sphere Z is on top of bottom sphere
// plus 1/4 of its diameter
middleZ = bottomZ + bottomDia/2 + middleDia/4;
// top sphere Z is on top of middle sphere
// plus 1/4 of its diameter
topZ = middleZ + middleDia/2 + topDia/4;

// hat brim diameter 20% larger than top sphere
hatBrimDia = topDia * 1.2;
hatBrimHeight = hatBrimDia * 0.1;
// hat height same as hat brim diameter
hatHeight = hatBrimDia * 0.6;
// hat top diameter 80% of hat brim diameter
hatTopDia = hatBrimDia * 0.6;
// hat Z is on top of top sphere
hatZ = topZ + topDia/2 - hatBrimHeight;

// top hat on top of top sphere
translate([0,0,hatZ]) {
    cylinder(d=hatBrimDia,h=hatBrimHeight);
    cylinder(d=hatTopDia,h=hatHeight);
}


// bottom sphere
translate([0,0,bottomZ]) {
    sphere(d=bottomDia);
}

// middle sphere on top of bottom sphere
translate([0,0,middleZ]) {
    sphere(d=middleDia);
}

// top sphere on top of middle sphere
translate([0,0,topZ]) {
    sphere(d=topDia);
}
