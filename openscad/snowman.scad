snowmanHeight = 100;
bottomDia = snowmanHeight/2;
middleDia = snowmanHeight/3;
topDia = snowmanHeight - middleDia - bottomDia;
// bottom sphere Z is half of its diameter
bottomZ = bottomDia/2;
// middle sphere Z is on top of bottom sphere
// plus 1/4 of its diameter
middleZ = bottomZ + bottomDia/2;
// middleZ = bottomDia + middleDia/4;
// top sphere Z is on top of middle sphere
// plus 1/4 of its diameter



topZ = bottomDia + middleDia + topDia/4;

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
