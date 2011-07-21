/**
  Copyright (C) 2011 by HSMWorks ApS
  All rights reserved.

  Redirect configuration.

  $Revision: 26199 $
  $Date: 2011-07-10 20:49:35 +0200 (sø, 10 jul 2011) $
*/

description = "Redirect";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2011 HSMWorks ApS";
certificationLevel = 2;

extension = "redir";
// using user code page

allowHelicalMoves = true;
allowSpiralMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
maximumCircularSweep = toRad(1000000);

function onOpen() {
}

function onDwell() {
}

function onCycle() {
}

function onCyclePoint() {
}

function onCycleEnd() {
}

function onRapid() {
}

function onLinear() {
}

function onRapid5D() {
}

function onLinear5D() {
}

function onCircular() {
}

function onCommand(command) {
}

function onSectionEnd() {
}

function onClose() {
}

function quote(text) {
  var result = "";
  for (var i = 0; i < text.length; ++i) {
    var ch = text.charAt(i);
    switch (ch) {
    case "\"":
      result += "\"";
    }
    result += ch;
  }
  return "\"" + result + "\"";
}

function onTerminate() {
  var outputPath = getOutputPath();
  var postPath = findFile("setup-sheet-excel.cps");
  var intermdiatePath = FileSystem.replaceExtension(outputPath, "cnc");
  var arguments = "--property unit 0"; // use 0 for inch and 1 for mm
  arguments += " --property programName \"" + programName + "\"";
  arguments += " --property programComment \"" + programComment + "\"";
  arguments += " --log temp.log " + quote(postPath) + " " + quote(intermdiatePath) + " " + quote(outputPath);
  var exePath = "C:\\Program Files\\HSMWorks x64\\post.exe";
  execute("post.exe", arguments, false, "");
}
