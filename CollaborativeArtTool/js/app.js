
// Outermost scope,
// You can access these variables from *anywhere*, in fxns, or in html
let myP5 = undefined
let mode = "mandala" // defines the drawing tool being used
let mousePositions = [] // holds the history of mouse positions
let mandalaCounter = 0
let MAXMANDALA = 3
let imgCount = 0
let autodraw = false
let currentBackground = [360,100,100]

function clearCanvas() {
	myP5.background(360,100,100)
	currentBackground = [360,100,100]
}

function changeBackground(playerBackground){
	myP5.background(playerBackground[0],playerBackground[1],playerBackground[2])
}

function rainbowClearCanvas() {
	currentBackground = [Math.random()*360,85,80]
	changeBackground(currentBackground)
}

function downloadCanvas() {
	imgName = "img" + imgCount;
	myP5.saveCanvas(imgName,"jpeg");
	imgCount = imgCount + 1;
}

function storeCanvas(){
	var canvas = document.getElementById('defaultCanvas0');
	var dataURL = canvas.toDataURL("image/jpeg");

	// const xhttp = new XMLHttpRequest(); // possible AJAX call if needed
  // xhttp.onload = function() {
  //   document.getElementById("demo").innerHTML =
  //   this.responseText;
  // }
  // xhttp.open("GET", "ajax_info.txt");
  // xhttp.send();
}

function drawWithTool(toolMode, mandalaCounter, mousePositions, mouseX, mouseY, p){
	switch(toolMode) {
		// traces strokes in a number of sides based on the mandala counter
		case "mandala":
			let numSides = mandalaCounter + 3;
			// console.log(numSides)

			p.push();
			p.translate(p.width/2,p.height/2)
			p.fill(2,82,53);

			for(var i = 0; i < numSides; i++){
				// rotate to give pseudo-symmetry
				p.rotate(1*Math.PI/numSides*i);
				if(mousePositions.length>8){
					// use triangles to draw strokes from user
					p.beginShape()
					p.vertex(...(mousePositions[mousePositions.length-1]))
					p.vertex(...(mousePositions[mousePositions.length-4]))
					p.vertex(...(mousePositions[mousePositions.length-8]))
					p.endShape()
				}
			}
			p.pop();
			break;

		case "spray":
			// spray pixels to color at mouse position
			p.loadPixels();
			// Get the current mouse position
			let x = Math.floor(mouseX)
			let y = Math.floor(mouseY)
			let currentColor = p.get(x, y)
			let xstep = 70
			let ystep = 50
			// blend to blue color
			let blendColor = [161,181,247,255]
			let newColor = vector.lerp(currentColor, blendColor, 0.1)
			for(var j = 0; j<xstep; j++){
				let x2 = x + j;
				// skip between every 4 and 7 pixels
				if(x2 % (4+Math.floor(3*Math.random())) == 0){
					continue;
				}

				for(var k = 0; k<ystep; k++){
					let y2 = y+k;
					// skip between every 3 and 5 pixels
					if(y2 % (3+Math.floor(2*Math.random())) == 0){
						continue;
					}
					currentColor = p.get(x2,y)
					newColor = vector.lerp(currentColor, blendColor, 0.1)
					p.set(x2, y2, newColor)
				}
			}
			p.updatePixels();

			break;

		case "anchor":

			// The current vector
			let p0 = [p.mouseX, p.mouseY]
			p.fill(176,82,53)
			p.circle(...p0,10)
			// start right above the circle
			p0[0] += 5

			// get 3 random positions
			let randPosn = []
			for(var i = 0; i<3; i++){
				randPosn.push([100*Math.random(),100*Math.random()])
			}
			let cp0 = vector.getAdd(p0,randPosn[0])
			let cp1 = vector.getAdd(cp0, randPosn[1])
			let p1 = vector.getAdd(p0,randPosn[2]);
			p.noFill()
			p.stroke("black")
			p.bezier(...p0, ...cp0, ...cp1, ...p1)

			break;

		default:
			console.warn("UNKNOWN TOOL:" + mode)
	}

}

// Lets broadcast that to the host,
//  or if we are the host, tell all the other players
function drawAndBroadcast(toolMode, mandalaCounter, mousePositions, mouseX, mouseY, p) {
	// You may want to modify the tool data, right now its just size and color

	let data = {
		toolMode: pt,
		mandalaCounter: mandalaCounter,
		mousePositions: mousePositions,
		mouseX: mouseX,
		mouseY: mouseY,
		p: p,
	}

	// Broadcast it, and draw it to my own canvas
	io.broadcastMove(data)
	drawWithTool(toolMode, mandalaCounter, mousePositions, mouseX, mouseY, p)
},



document.addEventListener("DOMContentLoaded", function(){
	console.log("Collaborative Art Tool")
	new Vue({
		el: '#networkControls',
		template: `<div id="networkControls">
					<div v-if="io.isHost">
						<span style="color:blue">host:</span>
						<span class="uid">"{{io.roomID}}"</span>
						<div class="section">
							connected to:
							<div v-for="connectedPeer in io.guestConnections">
								<span class="uid">{{connectedPeer.peer}}</span>
							</div>
							<div v-if="io.guestConnections.length === 0" style="font-style:italic">no-one connected yet</div>
						</div>
					</div>
					<div v-else-if="io.isGuest">
						<span style="color:green">guest:</span>
						<span class="uid">"{{io.roomID}}"</span>
						<div style="font-size: 70%">guest id: <span class="uid">{{io.guestID}}</span></div>
					</div>
					<div v-else>
						<span style="color:purple">awaiting connection...</span>
						Room id:<input v-model="io.roomID"></input>
						<button @click="io.hostRoom()">create room</button>
						<button @click="io.joinRoom()">join room</button>
					</div>
				</div>`,
		data() {
						return {
							io: io,
							mode: mode,
							mousePositions: mousePositions,
							mandalaCounter: mandalaCounter,
							p: p
						}
					}
	})

  // Initialize networking
	io.init()

	// Create the processing instance, and store it in myP5,
	// where we can access it anywhere in the code
	let element = document.getElementById("main")
	myP5 = new p5(

		// Run after processing is initialized
		function(p) {

			p.setup = () => {

				console.log("Do setup", p)

				p.createCanvas(900, 300);
				p.colorMode(p.HSL);

				// Hue, Sat, Light
				// (0-360,0-100,0-100)
				p.background("white")


			}

			p.mouseReleased = () => {
				// changes the number of sides that the mandala tool uses
				mandalaCounter = (mandalaCounter + 1) % MAXMANDALA;
			}

			p.mouseDragged = () => {
				let t = p.millis()*.001

				// Save this current mouse position in an array with origin in center
				mousePositions.push([p.mouseX-p.width/2, p.mouseY-p.height/2])

				drawAndBroadcast(mode, mandalaCounter, mousePositions, p.mouseX, p.mouseY, p)

			},

			p.draw = () => {
				// Not updating the background
				let t = p.millis()*.001

				// Draw the text box to label the drawing tool used tool
				p.noStroke()
				p.fill("white")
				p.rect(0, 0, 90, 30)
				p.fill("black")
				p.textSize(10)
				p.text("TOOL " + mode, 5, 20)
			}
		},

		// A place to put the canvas
		element);
})
