/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Dump configuration.

  $Revision: 25576 $
  $Date: 2011-05-31 00:27:15 +0200 (ti, 31 maj 2011) $
  
  FORKID {4E9DFE89-DA1C-4531-98C9-7FECF672BD47}
*/

description = "Dumper";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "dmp";
// using user code page

allowHelicalMoves = true;
allowSpiralMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
maximumCircularSweep = toRad(1000000);

var spatialFormat = createFormat({decimals:6});
var angularFormat = createFormat({decimals:6, scale:DEG});

function toString(value) {
  if (typeof(value) == 'string') {
    return "'" + value + "'";
  } else {
    return value;
  }
}

function dumpImpl(name, text) {
  writeln(getCurrentRecordId() + ": " + name + "(" + text + ")");  
}

function dump(name, arguments) {
  var result = getCurrentRecordId() + ": " + name + "(";
  for (var i = 0; i < arguments.length; ++i) {
    if (i > 0) {
      result += ", ";
    }
    if (typeof(arguments[i]) == 'string') {
      result += "'" + arguments[i] + "'";
    } else {
      result += arguments[i];
    }
  }
  result += ")";
  writeln(result);  
}

function onOpen() {
  dump("onOpen", arguments);
}

function onPassThrough() {
  dump("onPassThrough", arguments);
}

function onComment() {
  dump("onComment", arguments);
}

function onSection() {
  dump("onSection", arguments);

  var name;
  for (name in currentSection) {
    value = currentSection[name];
    if (typeof(value) != 'function') {
      writeln("  currentSection." + name + "=" + toString(value));
    }
  }

  for (name in tool) {
    value = tool[name];
    if (typeof(value) != 'function') {
      writeln("  tool." + name + "=" + toString(value));
    }
  }

  if (currentSection.isPatterned && currentSection.isPatterned()) {
    var patternId = currentSection.getPatternId();
    var sections = [];
    var first = true;
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var section = getSection(i);
      if (section.getPatternId() == patternId) {
        if (i < getCurrentSectionId()) {
          first = false; // not the first pattern instance
        }
        if (i != getCurrentSectionId()) {
          sections.push(section.getId());
        }
      }
    }
    writeln("  >>> Pattern instances: " + sections);
    if (!first) {
      // writeln("  SKIPPING PATTERN INSTANCE");
      // skipRemainingSection();
    }
  }
}

function onParameter() {
  dump("onParameter", arguments);
}

function onDwell() {
  dump("onDwell", arguments);
}

function onCycle() {
  dump("onCycle", arguments);

  writeln("  cycleType=" + toString(cycleType));
  for (var name in cycle) {
    value = cycle[name];
    if (typeof(value) != 'function') {
      writeln("  cycle." + name + "=" + toString(value));
    }
  }
}

function onCyclePoint() {
  dump("onCyclePoint", arguments);
}

function onCycleEnd() {
  dump("onCycleEnd", arguments);
}

function onMovement(movement) {
  dumpImpl("onMovement", movement + " /*" + getMovementStringId(movement) + "*/");
}

var RADIUS_COMPENSATION_MAP = {0:"off", 1:"left", 2:"right"};

function onRadiusCompensation() {
  dump("onRadiusCompensation", arguments);
  writeln("  radiusCompensation=" + radiusCompensation + " // " + RADIUS_COMPENSATION_MAP[radiusCompensation]);
}

function onRapid() {
  dump("onRapid", arguments);
}

function onLinear() {
  dump("onLinear", arguments);
}

function onRapid5D() {
  dump("onRapid5D", arguments);
}

function onLinear5D() {
  dump("onLinear5D", arguments);
}

function onCircular() {
  dump("onCircular", arguments);
  writeln("  sweep: " + angularFormat.format(getCircularSweep()) + "deg");
  if (isSpiral()) {
    writeln("  spiral");
    writeln("  start radius: " + spatialFormat.format(getCircularStartRadius()));
    writeln("  end radius: " + spatialFormat.format(getCircularRadius()));
    writeln("  delta radius: " + spatialFormat.format(getCircularRadius() - getCircularStartRadius()));
  } else {
    writeln("  radius: " + spatialFormat.format(getCircularRadius()));
  }
  if (isHelical()) {
    writeln("  helical pitch: " + spatialFormat.format(getHelicalPitch()));
  }
}

function onCommand(command) {
  dumpImpl("onCommand", command + " /*" + getCommandStringId(command) + "*/");
}

function onSectionEnd() {
  dump("onSectionEnd", arguments);
}

function onClose() {
  dump("onClose", arguments);
}
