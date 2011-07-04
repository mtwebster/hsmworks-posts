/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Validating post processor configuration.

  $Revision: 24282 $
  $Date: 2011-03-07 17:35:20 +0100 (ma, 07 mar 2011) $
  
  FORKID {FBC514E8-7C78-43e8-88AC-8FD457581764}
*/

description = "Validator";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "chk";
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

var openActive = false;
var sectionActive = false;
var cycleActive = false;

function onOpen() {
  writeln("Validating NC data...");
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(!openActive);
  openActive = true;
  validate(!cycleActive);
}

function onSection() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(!sectionActive);
  sectionActive = true;
  validate(!cycleActive);
}

function onRapid(x, y, z) {
  validate(arguments.length == 3, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active for onRapid()."));
}

function onLinear(x, y, z, feed) {
  validate(arguments.length == 4, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active for onLinear()."));
}

function onRapid5D(x, y, z, a, b, c) {
  validate(arguments.length == 6, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active for onRadous5D()."));
}

function onLinear5D(x, y, z, a, b, c, feed) {
  validate(arguments.length == 7, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active for onLinear5D()."));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  validate(arguments.length == 8, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active for onCircular()."));
}

var currentRadiusCompensation = RADIUS_COMPENSATION_OFF;

function onRadiusCompensation() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(currentRadiusCompensation != radiusCompensation, localize("Radius compensation has not changed."));

  switch (radiusCompensation) {
  case RADIUS_COMPENSATION_LEFT:
    validate(currentRadiusCompensation == RADIUS_COMPENSATION_OFF, localize("Radius compensation is not off."));
    break;
  case RADIUS_COMPENSATION_RIGHT:
    validate(currentRadiusCompensation == RADIUS_COMPENSATION_OFF, localize("Radius compensation is not off."));
    break;
  default:
    validate(currentRadiusCompensation == RADIUS_COMPENSATION_LEFT || currentRadiusCompensation == RADIUS_COMPENSATION_RIGHT, localize("Radius compensation is not active."));
  }
  currentRadiusCompensation = radiusCompensation;
}

function onParameter(name, value) {
  if (name == "operation-comment") {
    log(localize("Processing") + ": " + value);
  }
  validate(arguments.length == 2, localize("Mismatching arguments."));
  validate(openActive, localize("Stream has not been opened."));
}

function onDwell(seconds) {
  validate(arguments.length == 1, localize("Mismatching arguments."));
  validate(seconds >= 0, localize("Invalid dwelling time."));
}

function onCycle() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(!cycleActive, localize("Cycle is already active."));
  cycleActive = true;
  validate(cycleType != "", localize("Invalid cycle type."));
  validate(cycle, localize("Invalid cycle parameters."));
}

function onCyclePoint(x, y, z) {
  validate(arguments.length == 3, localize("Mismatching arguments."));
  validate(cycleActive, localize("Cycle is not active."));
  validate(typeof(cycle) == 'object', localize("Invalid cycle parameters."));

  if (isWellKnownCycle()) {
    validate(cycle.clearance >= cycle.retract, localize("Clearance below retract plane."));
    validate(cycle.retract >= cycle.stock, localize("Retract below stock plane."));
    validate(cycle.depth >= 0, localize("Depth is negative."));
    validate(cycle.feedrate >= 0, localize("Feedrate is negative."));
    validate((cycle.retractFeedrate == undefined) || (cycle.retractFeedrate >= 0), localize("Retract feedrate is negative."));
    validate((cycle.plungeFeedrate == undefined) || (cycle.plungeFeedrate >= 0), localize("Plunge feedrate is negative."));
    validate((cycle.dwell == undefined) || (cycle.dwell >= 0), localize("Dwell is negative."));
    validate((cycle.incrementalDepth == undefined) || (cycle.incrementalDepth >= 0), localize("Incremental depth is negative."));
    validate((cycle.accumulatedDepth == undefined) || (cycle.accumulatedDepth >= 0), localize("Accumulated depth is negative."));
    validate((cycle.plungesPerRetract == undefined) || (cycle.plungesPerRetract >= 1), localize("Plunges per retract is below 1."));
    validate((cycle.shift == undefined) || (cycle.shift >= 0), localize("Shit is negative."));
    // cycle.shiftAngle is don't care
    validate((cycle.backBoreDistance == undefined) || (cycle.backBoreDistance >= 0), localize("Back bore distance is negative."));
  }
  
  switch (cycleType) {
  case "drilling": // use G82
    break;
  case "counter-boring":
    validate(cycle.dwell != undefined, localize("Dwell is undefined."));
    break;
  case "chip-breaking":
    validate(cycle.dwell != undefined, localize("Dwell is undefined."));
    validate((cycle.dwell != undefined) && (cycle.incrementalDepth != undefined) && (cycle.accumulatedDepth != undefined));
    break;
  case "deep-drilling":
    validate(cycle.dwell != undefined, localize("Dwell is undefined."));
    validate(cycle.incrementalDepth != undefined);
    break;
  case "tapping":
    if (tool.type == TOOL_TAP_LEFT_HAND) {
      validate(!tool.clockwise, localize("Wrong spindle direction."));
    } else {
      validate(tool.clockwise, localize("Wrong spindle direction."));
    }
    break;
  case "left-tapping":
    validate(!tool.clockwise, localize("Wrong spindle direction."));
    break;
  case "right-tapping":
    validate(tool.clockwise, localize("Wrong spindle direction."));
    break;
  case "fine-boring":
    validate(cycle.shift != undefined, localize("Shift is undefined."));
    break;
  case "back-boring":
    validate(cycle.backBoreDistance != undefined, localize("Back bore distance is undefined."));
    break;
  case "reaming":
    validate(cycle.retractFeedrate != undefined, localize("Retract feedrate is undefined."));
    break;
  case "stop-boring":
    validate(cycle.dwell != undefined, localize("Dwell is undefined."));
    break;
  case "manual-boring":
    validate(cycle.dwell != undefined, localize("Dwell is undefined."));
    break;
  case "boring":
    validate(cycle.retractFeedrate != undefined, localize("Retract feedrate is undefined."));
    break;
  default:
    // ignore unknown cycles
  }
}

function onCycleEnd() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(cycle, localize("Invalid cycle parameters."));
  validate(cycleActive, localize("Cycle is not active for onCycleEnd()."));
  cycleActive = false;
}

function onSectionEnd() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(sectionActive, localize("Section is not active."));
  validate(!cycleActive, localize("Cycle is active at end of section."));
  sectionActive = false;
}

function onClose() {
  validate(arguments.length == 0, localize("Mismatching arguments."));
  validate(!sectionActive, localize("Section is active."));
  validate(openActive, localize("Stream is not open."));
  validate(!cycleActive, localize("Cycle is active."));
  openActive = false;

  writeln("NC data is valid.");
}
