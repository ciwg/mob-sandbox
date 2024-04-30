snowmanHeight = 100;
bottomDia = snowmanHeight/2;
middleDia = snowmanHeight/3;
topDia = snowmanHeight - middleDia - bottomDia;
bottomZ = bottomDia/2;
middleZ = bottomZ + middleDia/2;
topZ = middleZ + topDia/2;

// bottom sphere
translate([0,0,bottomZ]) {
    sphere(bottomDia);
}

// middle sphere on top of bottom sphere
translate([0,0,middleZ]) {
    sphere(middleDia);
}

// top sphere on top of middle sphere
translate([0,0,topZ]) {
    sphere(topDia);
}
