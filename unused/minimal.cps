/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Minimal post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {96F3CC76-19C0-4828-BF27-6A50AED3B187}
*/

description = "Minimal Heidenhain";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "h";
setCodePage("ansi");

var spindleAxisTable = new Table(["X", "Y", "Z"]);

var radiusCompensationTable = new Table(
  [" R0", " RL", " RR"],
  {initial:RADIUS_COMPENSATION_OFF, unchanged:" R"},
  "Invalid radius compensation"
);

var mFormat = createFormat({decimals:0});

var xyzFormat = createFormat({decimals:3, forceSign:true});
var abcFormat = createFormat({decimals:3, forceSign:true, scale:DEG});
var feedFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});

var xOutput = createVariable({prefix:" X"}, xyzFormat);
var yOutput = createVariable({prefix:" Y"}, xyzFormat);
var zOutput = createVariable({prefix:" Z"}, xyzFormat);
var feedOutput = createVariable({prefix:" F"}, feedFormat);

var blockNumber = 0;

/**
  Writes the specified block.
*/
function writeBlock(block) {
  writeln(blockNumber + SP + block);
  ++blockNumber;
}

function onOpen() {
  writeBlock(
    "BEGIN PGM" + (programName ? (SP + programName) : "") + ((unit == MM) ? " MM" : " IN")
  );
  writeBlock(mFormat.format(3)); // spindle on - clockwise

  machineConfiguration.setRetractPlane(-1.0); // safe machine retract plane (M91)
}

/**
  Invalidates the current position and feedrate. Invoke this function to
  force X, Y, Z, A, B, C, and F in the following block.
*/
function invalidate() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  feedOutput.reset();
}

function onSection() {
  writeBlock("L Z" + xyzFormat.format(machineConfiguration.getRetractPlane()) + " M91");
  var retracted = true;

  writeBlock(
    "TOOL CALL " + tool.number + SP + spindleAxisTable.lookup(spindleAxis) + " S" + rpmFormat.format(tool.spindleRPM)
  );

  setTranslation(currentSection.workOrigin);
  setRotation(currentSection.workPlane);

  invalidate();
  
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock("L" + zOutput.format(initialPosition.z) + " FMAX");
    }
  }
  writeBlock("L" + xOutput.format(initialPosition.x) + yOutput.format(initialPosition.y) + zOutput.format(initialPosition.z));
}

function onRapid(x, y, z) {
  writeBlock("L" + xOutput.format(x) + yOutput.format(y) + zOutput.format(z) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");
  feedOutput.reset();
}

function onLinear(x, y, z, feed) {
  writeBlock(
    "L" + xOutput.format(x) + yOutput.format(y) + zOutput.format(z) + radiusCompensationTable.lookup(radiusCompensation) + feedOutput.format(feed)
  );
}

function onSectionEnd() {
  // full retract in machine coordinate system
  writeBlock("L Z" + xyzFormat.format(machineConfiguration.getRetractPlane()) + " M91");
  invalidate();
}

function onClose() {
  writeBlock(mFormat.format(0)); // stop program, spindle stop, coolant off
  writeBlock(
    "END PGM" + (programName ? (SP + programName) : "") + ((unit == MM) ? " MM" : " IN")
  );
}
