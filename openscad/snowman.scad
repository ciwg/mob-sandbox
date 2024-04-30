snowmanHeight = 100;
bottomDia = snowmanHeight/2;
middleDia = snowmanHeight/3;
topDia = snowmanHeight - middleDia - bottomDia;

// bottom sphere
sphere(bottomDia);

// middle sphere on top of bottom sphere
translate([0,0,bottomDia]) {
    sphere(middleDia);
}

// top sphere on top of middle sphere
translate([0,0,bottomDia+middleDia]) {
    sphere(topDia);
}
