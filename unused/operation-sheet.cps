/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Operation sheet configuration.

  $Revision: 5667 $
  $Date: 2006-06-27 08:42:08 +0200 (Tue, 27 Jun 2006) $
  
  FORKID {B9BC9FEF-BEEC-453e-9595-EBE4DF935328}
*/

description = "Operation Sheet";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "html";
mimetype = "text/html";
keywords = "MODEL_IMAGE";
setCodePage("utf-8");

properties = {
  embedStylesheet: true, // embeds the stylesheet
  useUnitSymbol: false, // specifies that symbols should be used for units (some printers may not support this)
  showDocumentPath: true, // specifies that the path of the source document should be shown
  showModelImage: true, // specifies that the model image should be shown
  showToolImage: true, // specifies that the tool image should be shown
  showPercentages: true, // specifies that the percentage of the total cycle time should be shown for each operation cycle time
  showFooter: true,
  showRapidDistance: true,
  rapidFeed: 10000, // the rapid traversal feed
  toolChangeTime: 15, // the time in seconds for a tool change
  showNotes: true // show notes for the operations
};

var feedFormat = createFormat({decimals:(unit == MM ? 0 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:3});
var spatialFormat = createFormat({decimals:(unit == MM ? 2 : 3)});
var percentageFormat = createFormat({decimals:1, scale:100});
var timeFormat = createFormat({decimals:2});
var taperFormat = angleFormat; // share format

// collected state
var zRanges = {};
var totalCycleTime = 0;
var exportedTools = {};
var hasRadiusCompensation;
var toolRenderer;

function getUnitSymbolAsString() {
  switch (unit) {
  case MM:
    return properties.useUnitSymbol ? "&#x339c;" : "mm";
  case IN:
    return properties.useUnitSymbol ? "&#x2233;" : "in";
  default:
    error(localize("Unit is not supported."));
    return undefined;
  }
}

function getFeedSymbolAsString() {
  switch (unit) {
  case MM:
    return properties.useUnitSymbol ? "&#x339c;/min" : "mm/min";
  case IN:
    return properties.useUnitSymbol  ? "&#x2233;/min" : "in/min";
    // return properties.useUnitSymbol  ? "&#x2032;/min" : "ft/min";
  default:
    error(localize("Unit is not supported."));
    return undefined;
  }
}

function toString(value) {
  if (typeof(value) == 'string') {
    return "'" + value + "'";
  } else {
    return value;
  }
}

function makeRow(content, classId) {
  if (classId) {
    return "<tr class=\"" + classId + "\">" + content + "</tr>";
  } else {
    return "<tr>" + content + "</tr>";
  }
}

function makeHeading(content, classId) {
  if (classId) {
    return "<th class=\"" + classId + "\">" + content + "</th>";
  } else {
    return "<th>" + content + "</th>";
  }
}

function makeColumn(content, classId) {
  if (classId) {
    return "<td class=\"" + classId + "\">" + content + "</td>";
  } else {
    return "<td>" + content + "</td>";
  }
}

function bold(content, classId) {
  if (classId) {
    return "<b class=\"" + classId + "\">" + content + "</b>";
  } else {
    return "<b>" + content + "</b>";
  }
}

function d(content) {
  return "<div class=\"description\" style=\"display: inline;\">" + content + "</div>";
}

function v(content) {
  return "<div class=\"value\" style=\"display: inline;\">" + content + "</div>";
}

function p(content, classId) {
  if (classId) {
    return "<p class=\"value\">" + content + "</p>";
  } else {
    return "<p>" + content + "</p>";
  }
}

function onRadiusCompensation() {
  hasRadiusCompensation |= radiusCompensation != RADIUS_COMPENSATION_OFF;
}

var cachedParameters = {};

function onParameter(name, value) {
  cachedParameters[name] = value;
}

function onOpen() {
  cachedParameters = {};
  
  toolRenderer = createToolRenderer();
  toolRenderer.setBackgroundColor(new Color(1, 1, 1));
  toolRenderer.setFluteColor(new Color(25.0/255, 25.0/255, 200.0/255));
  toolRenderer.setShoulderColor(new Color(25.0/255, 150.0/255, 25.0/255));
  toolRenderer.setShaftColor(new Color(140.0/255, 140.0/255, 0.0));

  if (is3D()) {
    var numberOfSections = getNumberOfSections();
    for (var i = 0; i < numberOfSections; ++i) {
      var section = getSection(i);
      var zRange = section.getGlobalZRange();
      var tool = section.getTool();
      if (zRanges[tool.number]) {
        zRanges[tool.number].expandToRange(zRange);
      } else {
        zRanges[tool.number] = zRange;
      }
    }
  }

  write(
    "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n" +
    "                      \"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n"
  );
  write("<html>");
  // header
  var c = "<head>";
  c += "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">";
  if (properties.embedStylesheet) {
    c += "<style type=\"text/css\">" + loadText("setup-sheet.css", "utf-8") + "</style>";
  } else {
    c += "<link rel=\"StyleSheet\" href=\"setup-sheet.css\" type=\"text/css\" media=\"print, screen\">";
  }
  if (programName) {
    c += "<title>" + localize("Operation Sheet for Program") + " " + programName + "</title>";
  } else {
    c += "<title>" + localize("Operation Sheet") + "</title>";
  }
  c += "</head>";
  write(c);

  write("<body>");
  if (programName) {
    write("<h1>" + localize("Operation Sheet for Program") + " " + programName + "</h1>");
  } else {
    write("<h1>" + localize("Operation Sheet") + "</h1>");
  }
}

/**
  Returns the specified coolant as a string.
*/
function getCoolantDescription(coolant) {
  switch (coolant) {
  case COOLANT_OFF:
    return localize("Off");
  case COOLANT_FLOOD:
    return localize("Flood");
  case COOLANT_MIST:
    return localize("Mist");
  case COOLANT_THROUGH_TOOL:
    return localize("Through tool");
  case COOLANT_AIR:
    return localize("Air");
  case COOLANT_AIR_THROUGH_TOOL:
    return localize("Air through tool");
  case COOLANT_SUCTION:
    return localize("Suction");
  case COOLANT_FLOOD_MIST:
    return localize("Flood and mist");
  case COOLANT_FLOOD_THROUGH_TOOL:
    return localize("Flood and through tool");
  default:
    return localize("Unknown");
  }
}

function onSection() {
  skipRemainingSection();
}

function onSectionEnd() {
  if (isFirstSection()) {
    var c = "";
    if (hasParameter("job-description")) {
      var description = getParameter("job-description");
      if (description) {
        c += makeRow(makeColumn(d(localize("Job Description") + ": ") + v(description)));
      }
    }

    if (hasParameter("iso9000/document-control")) {
      var id = getParameter("iso9000/document-control");
      if (id) {
        c += makeRow(makeColumn(d(localize("Job ISO-9000 Control") + ": ") + v(id)));
      }
    }

    if (hasParameter("document-path") && properties.showDocumentPath) {
      var path = getParameter("document-path");
      if (path) {
        c += makeRow(makeColumn(d(localize("Document Path") + ": ") + v(path)));
      }
    }

    if (properties.showNotes && hasParameter("job-notes")) {
      var notes = getParameter("job-notes");
      if (notes) {
        c +=
          "<tr class=\"notes\"><td valign=\"top\">" +
          d(localize("Notes")) + ": " + getParameter("job-notes") +
          "</td></tr>";
      }
    }

    if (c) {
      write("<table class=\"jobhead\" align=\"center\">" + c + "</table>");
      write("<br>");
      writeln("");
      writeln("");
    }

/*
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero() || modelImagePath && properties.showModelImage) {

      write("<table class=\"job\" cellspacing=\"0\" align=\"center\">");
      write(makeRow("<th colspan=\"2\">" + localize("Job") + "</th>"));
      write("<tr>");

      var numberOfColumns = 0;
      { // stock - workpiece
        if (delta.isNonZero()) {
          var c = "<table class=\"info\" cellspacing=\"0\">";

          var workOffset = undefined;
          var multipleWCS = false;
          var numberOfSections = getNumberOfSections();
          for (var i = 0; i < numberOfSections; ++i) {
            var section = getSection(i);
            if (!workOffset) {
              workOffset = section.workOffset;
            }
            if (workOffset != section.workOffset) {
              multipleWCS = true;
              break;
            }            
          }
          c += makeRow(makeColumn(d(localize("WCS")) + ": #" + workOffset));
 
          if (multipleWCS) {
            c += makeRow(makeColumn(d(localize("Program uses multiple WCS!"))));
          }

          c += makeRow(makeColumn(
            d(localize("Stock")) + ": <br>&nbsp;&nbsp;" + v(localize("DX") + ": " + spatialFormat.format(delta.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DY") + ": " + spatialFormat.format(delta.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DZ") + ": " + spatialFormat.format(delta.z) + getUnitSymbolAsString())
          ));

          if (hasParameter("part-lower-x") && hasParameter("part-lower-y") && hasParameter("part-lower-z") &&
              hasParameter("part-upper-x") && hasParameter("part-upper-y") && hasParameter("part-upper-z")) {
            var lower = new Vector(getParameter("part-lower-x"), getParameter("part-lower-y"), getParameter("part-lower-z"));
            var upper = new Vector(getParameter("part-upper-x"), getParameter("part-upper-y"), getParameter("part-upper-z"));
            var delta = Vector.diff(upper, lower);
            c += makeRow(makeColumn(
              d(localize("Part")) + ": <br>&nbsp;&nbsp;" + v(localize("DX") + ": " + spatialFormat.format(delta.x) + getUnitSymbolAsString() + "<br>&nbsp;&nbsp;" + v(localize("DY") + ": " + spatialFormat.format(delta.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DZ") + ": " + spatialFormat.format(delta.z) + getUnitSymbolAsString()))
            ));
          }

          c += makeRow(makeColumn(
            d(localize("Stock Lower in WCS") + " #" + workOffset) + ": <br>&nbsp;&nbsp;" + v("X: " + spatialFormat.format(workpiece.lower.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Y: " + spatialFormat.format(workpiece.lower.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Z: " + spatialFormat.format(workpiece.lower.z) + getUnitSymbolAsString())
          ));
          c += makeRow(makeColumn(
            d(localize("Stock Upper in WCS") + " #" + workOffset) + ": <br>&nbsp;&nbsp;" + v("X: " + spatialFormat.format(workpiece.upper.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Y: " + spatialFormat.format(workpiece.upper.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Z: " + spatialFormat.format(workpiece.upper.z) + getUnitSymbolAsString())
          ));

          c += "</table>";
          write(makeColumn(c));
          ++numberOfColumns;
        }
      }

      if (modelImagePath && properties.showModelImage) {
        ++numberOfColumns;
        var alignment = (numberOfColumns <= 1) ? "center" : "right";
        write("<td class=\"model\" align=\"" + alignment + "\"><img src=\"" + modelImagePath + "\"/></td>");
      }

      write("</tr>");
      write("</table>");
      write("<br>");
      writeln("");
      writeln("");
    }
*/

    writeTotals();
    write("<br>");

    writeln("<table class=\"sheet\" cellspacing=\"0\" align=\"center\">");
  }

  var c1 = "<table class=\"info\" cellspacing=\"0\">";

  c1 += makeRow(
    makeColumn(v(localize("Operation") + " " + (currentSection.getId() + 1) + "/" + getNumberOfSections()))
  );

  if (hasParameter("operation-comment")) {
    c1 += makeRow(
      makeColumn(d(localize("Description") + ": ") + v(getParameter("operation-comment")))
    );
  }

  if (hasParameter("operation-strategy")) {
    var strategies = {
      drill: localize("Drilling"),
      face: localize("Facing"),
      path3d: localize("3D Path"),
      pocket2d: localize("Pocket 2D"),
      contour2d: localize("Contour 2D"),
      adaptive2d: localize("Adaptive 2D"),
      
      contour_new: localize("Contour"),
      contour: localize("Contour"),
      parallel_new: localize("Parallel"),
      parallel: localize("Parallel"),
      pocket_new: localize("Pocket"),
      pocket: localize("Pocket"),
      adaptive: localize("Adaptive"),
      horizontal_new: localize("Horizontal"),
      horizontal: localize("Horizontal"),
      morph: localize("Morph"),
      pencil_new: localize("Pencil"),
      pencil: localize("Pencil"),
      project: localize("Project"),
      radial_new: localize("Radial"),
      radial: localize("Radial"),
      scallop_new: localize("Scallop"),
      scallop: localize("Scallop"),
      spiral_new: localize("Spiral"),
      spiral: localize("Spiral"),
      swarf: localize("Multi-Axis Swarf"),
      multiAxisContour: localize("Multi-Axis Contour")
    };
    var description = "";
    if (strategies[getParameter("operation-strategy")]) {
      description = strategies[getParameter("operation-strategy")];
    } else {
      description = localize("Unspecified");
    }
    c1 += makeRow(
      makeColumn(d(localize("Strategy") + ": ") + v(description))
    );
  }

  var newWCS = !isFirstSection() && (currentSection.workOffset != getSection(currentSection.getId()).workOffset);
  c1 += makeRow(
    makeColumn(d(localize("WCS") + ": ") + v("#" + currentSection.workOffset + (newWCS ? localize("NEW WCS!") : "")))
  );

  var tolerance = cachedParameters["operation:tolerance"];
  var stockToLeave = cachedParameters["operation:stockToLeave"];
  var axialStockToLeave = cachedParameters["operation:verticalStockToLeave"];
  var maximumStepdown = cachedParameters["operation:maximumStepdown"];
  var maximumStepover = cachedParameters["operation:maximumStepover"] ? cachedParameters["operation:maximumStepover"] : cachedParameters["operation:stepover"];

  if (tolerance != undefined) {
    c1 += makeRow(makeColumn(d(localize("Tolerance") + ": ") + v(spatialFormat.format(tolerance) + getUnitSymbolAsString())));
  }
  if (stockToLeave != undefined) {
    if ((axialStockToLeave != undefined) && (stockToLeave != axialStockToLeave)) {
      c1 += makeRow(
        makeColumn(
          d(localize("Stock to Leave") + ": ") + v(spatialFormat.format(stockToLeave) + getUnitSymbolAsString()) + "/" + v(spatialFormat.format(axialStockToLeave) + getUnitSymbolAsString())
        )
      );
    } else {
      c1 += makeRow(makeColumn(d(localize("Stock to Leave") + ": ") + v(spatialFormat.format(stockToLeave) + getUnitSymbolAsString())));
    }
  }

  if ((maximumStepdown != undefined) && (maximumStepdown > 0)) {
    c1 += makeRow(makeColumn(d(localize("Maximum stepdown") + ": ") + v(spatialFormat.format(maximumStepdown) + getUnitSymbolAsString())));
  }

  if ((maximumStepover != undefined) && (maximumStepover > 0)) {
    c1 += makeRow(makeColumn(d(localize("Maximum stepover") + ": ") + v(spatialFormat.format(maximumStepover) + getUnitSymbolAsString())));
  }

  var compensationType = (hasRadiusCompensation && hasParameter("operation:compensationType")) ? getParameter("operation:compensationType") : "computer";
  if (compensationType != "computer") {
    var compensationDeltaRadius = hasParameter("operation:compensationDeltaRadius") ? getParameter("operation:compensationDeltaRadius") : 0;

    var compensation = hasParameter("operation:compensation") ? getParameter("operation:compensation") : "center";
    var COMPENSATIONS = {left: localize("left"), right: localize("right"), center: localize("center")};
    var compensationText = localize("unspecified");
    if (COMPENSATIONS[compensation]) {
      compensationText = COMPENSATIONS[compensation];
    }

    var DESCRIPTIONS = {computer: localize("computer"), control: localize("control"), wear: localize("wear"), inverseWear: localize("inverse wear")};
    var description = localize("unspecified");
    if (DESCRIPTIONS[compensationType]) {
      description = DESCRIPTIONS[compensationType];
    }
    c1 += makeRow(makeColumn(d(localize("Compensation") + ": ") + v(description + " (" + compensationText + ")")));
    c1 += makeRow(makeColumn(d(localize("Safe Tool Diameter") + ": ") + v("< " + spatialFormat.format(tool.diameter + 2 * compensationDeltaRadius) + getUnitSymbolAsString())));
  }

  c1 += "</table>";

  var c2 = "<table class=\"info\" cellspacing=\"0\">";
  c2 += makeRow(makeColumn(v("&nbsp;"))); // move 1 row down

  if (is3D()) {
    var zRange = currentSection.getGlobalZRange();
    c2 += makeRow(makeColumn(d(localize("Maximum Z") + ": ") + v(spatialFormat.format(zRange.getMaximum()) + getUnitSymbolAsString())));
    c2 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRange.getMinimum()) + getUnitSymbolAsString())));
  }

  var maximumFeed = currentSection.getMaximumFeedrate();
  var maximumSpindleSpeed = currentSection.getMaximumSpindleSpeed();
  var cuttingDistance = currentSection.getCuttingDistance();
  var rapidDistance = currentSection.getRapidDistance();
  var cycleTime = currentSection.getCycleTime();

  c2 += makeRow(makeColumn(d(localize("Maximum Feedrate") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
  c2 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(maximumSpindleSpeed + localize("rpm"))));
  c2 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
  if (properties.showRapidDistance) {
    c2 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
  }
  if (properties.rapidFeed > 0) {
    cycleTime += rapidDistance/properties.rapidFeed;
  }
  var additional = "";
  if ((getNumberOfSections() > 1) && properties.showPercentages) {
    if (totalCycleTime > 0) {
      additional = "<div class=\"percentage\">(" + percentageFormat.format(cycleTime/totalCycleTime) + "%)</div>";
    }
  }
  c2 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime) + " " + additional)));
  c2 += makeRow(makeColumn(d(localize("Coolant") + ": ") + v(getCoolantDescription(tool.coolant))));
  
  c2 += "</table>";

  var c3 = "<table class=\"info\" cellspacing=\"0\">";
  c3 += makeRow(makeColumn("&nbsp;"));
  c3 += makeRow(
    makeColumn(
      bold(localize("T") + toolFormat.format(tool.number)) + " " +
      localize("D") + toolFormat.format(tool.diameterOffset) + " " +
      localize("L") + toolFormat.format(tool.lengthOffset)
    )
  );

  c3 += makeRow(makeColumn(d(localize("Type") + ": ") + v(getToolTypeName(tool.type))));
  c3 += makeRow(makeColumn(d(localize("Diameter") + ": ") + v(spatialFormat.format(tool.diameter) + getUnitSymbolAsString())));
  if (tool.cornerRadius) {
    c3 += makeRow(makeColumn(d(localize("Corner Radius") + ": ") + v(spatialFormat.format(tool.cornerRadius) + getUnitSymbolAsString())));
  }
  if (tool.taperAngle) {
    if (tool.isDrill()) {
      c3 += makeRow(makeColumn(d(localize("Tip Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
    } else {
      c3 += makeRow(makeColumn(d(localize("Taper Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
    }
  }
  c3 += makeRow(makeColumn(d(localize("Length") + ": ") + v(spatialFormat.format(tool.bodyLength) + getUnitSymbolAsString())));
  c3 += makeRow(makeColumn(d(localize("Flutes") + ": ") + v(tool.numberOfFlutes)));
  if (tool.comment) {
    c3 += makeRow(makeColumn(d(localize("Description") + ": ") + v(tool.comment)));
  }
  c3 += "</table>";

  var c4;
  if (properties.showToolImage) {
    var path = "tool" + tool.number + ".png";
    var width = 100;
    var height = 133;
    if (!exportedTools[tool.number]) {
      toolRenderer.exportAs(path, "image/png", tool, width, height);
      exportedTools[tool.number] = true; // do not export twice
    }
    c4 = "<table class=\"info\" cellspacing=\"0\">" +
      makeRow("<td class=\"image\"><img src=\"" + path + "\"/></td>") +
      "</table>";
  }

  write(
    "<tr class=\"info\">" +
      "<td valign=\"top\">" + c1 + "</td>" +
      "<td valign=\"top\">" + c2 + "</td>" +
      "<td valign=\"top\">" + c3 + "</td>" +
      (properties.showToolImage ? "<td valign=\"top\" align=\"center\">" + c4 + "</td>" : "") +
    "</tr>"
  );

  if (properties.showNotes && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      write(
        "<tr class=\"notes\"><td valign=\"top\" colspan=\"4\">" +
        d(localize("Notes")) + ": " + getParameter("notes") +
        "</td></tr>"
      );
    }
  }
  
  if (!isLastSection()) {
    write("<tr class=\"space\"><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>");
  }
  writeln("");
  writeln("");

  hasRadiusCompensation = false;
  cachedParameters = {};
}

function formatCycleTime(cycleTime) {
  cycleTime = cycleTime + 0.5; // round up
  var seconds = cycleTime % 60 | 0;
  var minutes = ((cycleTime - seconds)/60 | 0) % 60;
  var hours = (cycleTime - minutes * 60 - seconds)/(60 * 60) | 0;
  if (hours > 0) {
    return subst(localize("%1h:%2m:%3s"), hours, minutes, seconds);
  } else if (minutes > 0) {
    return subst(localize("%1m:%2s"), minutes, seconds);
  } else {
    return subst(localize("%1s"), seconds);
  }
}

function writeTotals() {
  var zRange;
  var maximumFeed = 0;
  var maximumSpindleSpeed = 0;
  var cuttingDistance = 0;
  var rapidDistance = 0;
  var cycleTime = 0;

  var numberOfSections = getNumberOfSections();
  var currentTool;
  for (var i = 0; i < numberOfSections; ++i) {
    var section = getSection(i);

    if (is3D()) {
      var _zRange = section.getGlobalZRange();
      if (zRange) {
        zRange.expandToRange(_zRange);
      } else {
        zRange = _zRange;
      }
    }
    
    maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
    maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
    cuttingDistance += section.getCuttingDistance();
    rapidDistance += section.getRapidDistance();
    cycleTime += section.getCycleTime();
    if (properties.rapidFeed > 0) {
      cycleTime += rapidDistance/properties.rapidFeed;
    }
    if (properties.toolChangeTime > 0) {
      var tool = section.getTool();
      if (currentTool != tool.number) {
        currentTool = tool.number;
        cycleTime += properties.toolChangeTime;
      }
    }
  }
  totalCycleTime = cycleTime;

  writeln("<table class=\"sheet\" cellspacing=\"0\" align=\"center\">");
  write(makeRow("<th>" + localize("Total") + "</th>"));

  var c1 = "<table class=\"info\" cellspacing=\"0\">";
  var tools = getToolTable();
  c1 += makeRow(makeColumn(d(localize("Number Of Operations") + ": ") + v(getNumberOfSections())));
  var text = "";
  for (var i = 0; i < tools.getNumberOfTools(); ++i) {
    var tool = tools.getTool(i);
    if (i > 0) {
      text += " ";
    }
    text += bold(localize("T") + toolFormat.format(tool.number));
  }
  c1 += makeRow(makeColumn(d(localize("Number Of Tools") + ": ") + v(tools.getNumberOfTools())));
  c1 += makeRow(makeColumn(d(localize("Tools") + ": ") + v(text)));
  if (zRange) {
    c1 += makeRow(makeColumn(d(localize("Maximum Z") + ": ") + v(spatialFormat.format(zRange.getMaximum()) + getUnitSymbolAsString())));
    c1 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRange.getMinimum()) + getUnitSymbolAsString())));
  }
  c1 += makeRow(makeColumn(d(localize("Maximum Feedrate") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
  c1 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(maximumSpindleSpeed + localize("rpm"))));
  c1 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
  if (properties.showRapidDistance) {
    c1 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
  }
  c1 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime))));
  c1 += "</table>";

  write(
    "<tr class=\"info\">" +
      "<td valign=\"top\">" + c1 + "</td>" +
    "</tr>"
  );
  write("</table>");
  writeln("");
  writeln("");
}

function onClose() {
  writeln("</table>");
  
  // footer
  if (properties.showFooter) {
    write("<br>");
    write("<div class=\"footer\">");
    var src = findFile("../graphics/HSMWorks-Logo.png");
    var dest = "HSMWorks-Logo.png";
    if (FileSystem.isFile(src)) {
      FileSystem.copyFile(src, FileSystem.getFolderPath(getOutputPath()) + "\\" + dest);
      write("<img class=\"logo\" src=\"" + dest + "\"/>");
    }
    var now = new Date();
    write(localize("Generated by ") + "<a href=\"http://www.hsmworks.com\">HSMWorks</a>" + " " + now.toLocaleDateString() + " " + now.toLocaleTimeString());
    write("</div");
  }
  write("</body>");
  write("</html>");
}
