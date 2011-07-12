/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Tool sheet configuration.

  $Revision: 25500 $
  $Date: 2011-05-24 21:04:29 +0200 (ti, 24 maj 2011) $
  
  FORKID {43EC4ED1-A199-41f8-85C1-6FF2C01946F6}
*/

description = "Tool Sheet";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "html";
mimetype = "text/html";
setCodePage("utf-8");

properties = {
  embedStylesheet: true, // embeds the stylesheet
  useUnitSymbol: false, // specifies that symbols should be used for units (some printers may not support this)
  showDocumentPath: true, // specifies that the path of the source document should be shown
  showToolImage: true, // specifies that the tool image should be shown
  showFooter: true, // specifies that the footer should be shown
  showPercentages: true, // specifies that the percentage of the total cycle time should be shown for each operation cycle time
  showRapidDistance: true,
  rapidFeed: 10000 // the rapid traversal feed
};

var feedFormat = createFormat({decimals:(unit == MM ? 0 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:3});

// presentation formats
var spatialFormat = createFormat({decimals:3});
var percentageFormat = createFormat({decimals:1, forceDecimal:true, scale:100});
var timeFormat = createFormat({decimals:2});
var taperFormat = angleFormat; // share format

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
  return "<div class=\"description\">" + content + "</div>";
}

function v(content) {
  return "<div class=\"value\">" + content + "</div>";
}

function p(content, classId) {
  if (classId) {
    return "<p class=\"value\">" + content + "</p>";
  } else {
    return "<p>" + content + "</p>";
  }
}

function onSection() {
  skipRemainingSection();
}

function onClose() {
  var toolRenderer = createToolRenderer();
  toolRenderer.setBackgroundColor(new Color(1, 1, 1));
  toolRenderer.setFluteColor(new Color(25.0/255, 25.0/255, 200.0/255));
  toolRenderer.setShoulderColor(new Color(25.0/255, 150.0/255, 25.0/255));
  toolRenderer.setShaftColor(new Color(140.0/255, 140.0/255, 0.0));

  var totalCycleTime = 0;
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    totalCycleTime += section.getCycleTime();
    // excluding tool change time
  }

  write(
    "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n" +
    "                      \"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n"
  );
  write("<html>");

  var zRanges = {};
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

  // header
  c = "<head>";
  c += "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">";
  if (programName) {
    c += "<title>" + localize("Tool Sheet for Program") + " " + programName + "</title>";
  } else {
    c += "<title>" + localize("Tool Sheet") + "</title>";
  }
  if (properties.embedStylesheet) {
    c += "<style type=\"text/css\">" + loadText("tool-sheet.css", "utf-8") + "</style>";
  } else {
    c += "<link rel=\"StyleSheet\" href=\"tool-sheet.css\" type=\"text/css\" media=\"print, screen\">";
  }
  c += "</head>";
  write(c);

  write("<body>");
  if (programName) {
    write("<h1>" + localize("Tool Sheet for Program") + " " + programName + "</h1>");
  } else {
    write("<h1>" + localize("Tool Sheet") + "</h1>");
  }

  {
    c = "";

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

    if (c) {
      write("<table class=\"jobhead\" align=\"center\">" + c + "</table>");
      write("<br>");
      writeln("");
      writeln("");
    }
  }

  write("<table class=\"sheet\" cellspacing=\"0\" align=\"center\"");
  var colgroup = "<colgroup span=\"3\"><col width=\"1*\"/><col width=\"1*\"/><col width=\"120\"/></colgroup>";
  write(colgroup);
  write(makeRow("<th colspan=\"3\">" + localize("Tools") + "</th>"));

  var tools = getToolTable();
  if (tools.getNumberOfTools() > 0) {
    for (var i = 0; i < tools.getNumberOfTools(); ++i) {
      var tool = tools.getTool(i);

      var c1 = "<table class=\"tool\">";
      c1 += makeRow(
        makeColumn(
          bold(localize("T") + toolFormat.format(tool.number)) + " " +
          localize("D") + toolFormat.format(tool.diameterOffset) + " " +
          localize("L") + toolFormat.format(tool.lengthOffset)
        )
      );
      c1 += makeRow(makeColumn(d(localize("Type") + ": ") + v(getToolTypeName(tool.type))));
      c1 += makeRow(makeColumn(d(localize("Diameter") + ": ") + v(spatialFormat.format(tool.diameter) + getUnitSymbolAsString())));
      if (tool.cornerRadius) {
        c1 += makeRow(makeColumn(d(localize("Corner Radius") + ": ") + v(spatialFormat.format(tool.cornerRadius) + getUnitSymbolAsString())));
      }
      if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
        if (tool.isDrill()) {
          c1 += makeRow(makeColumn(d(localize("Tip Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
        } else {
          c1 += makeRow(makeColumn(d(localize("Taper Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
        }
      }
      c1 += makeRow(makeColumn(d(localize("Length") + ": ") + v(spatialFormat.format(tool.bodyLength) + getUnitSymbolAsString())));
      c1 += makeRow(makeColumn(d(localize("Flutes") + ": ") + v(tool.numberOfFlutes)));
      if (tool.material) {
        c1 += makeRow(makeColumn(d(localize("Material") + ": ") + v(getMaterialName(tool.material))));
      }
      if (tool.comment) {
        c1 += makeRow(makeColumn(d(localize("Description") + ": ") + v(tool.comment)));
      }
      if (tool.vendor) {
        c1 += makeRow(makeColumn(d(localize("Vendor") + ": ") + v(tool.vendor)));
      }
      //c1 += "<tr class=\"thin\"><td width=\"6cm\">&nbsp;</td></tr>"; // fixed width
      c1 += "</table>";

      var c2 = "<table class=\"tool\">";
      c2 += makeRow(makeColumn("&nbsp;")); // move 1 row down
      if (zRanges[tool.number]) {
        c2 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRanges[tool.number].getMinimum()) + getUnitSymbolAsString())));
      }

      var maximumFeed = 0;
      var maximumSpindleSpeed = 0;
      var cuttingDistance = 0;
      var rapidDistance = 0;
      var cycleTime = 0;
      for (var j = 0; j < getNumberOfSections(); ++j) {
        var section = getSection(j);
        if (section.getTool().number == tool.number) {
          maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
          maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
          cuttingDistance += section.getCuttingDistance();
          rapidDistance += section.getRapidDistance();
          cycleTime += section.getCycleTime();
        }
      }
      if (properties.rapidFeed > 0) {
        cycleTime += rapidDistance/properties.rapidFeed;
      }

      c2 += makeRow(makeColumn(d(localize("Maximum Feed") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
      c2 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(maximumSpindleSpeed + localize("rpm"))));
      c2 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
      if (properties.showRapidDistance) {
        c2 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
      }
      var additional = "";
      if ((getNumberOfSections() > 1) && properties.showPercentages) {
        if (totalCycleTime > 0) {
          additional = "<div class=\"percentage\">(" + percentageFormat.format(cycleTime/totalCycleTime) + "%)</div>";
        }
      }
      c2 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime) + " " + additional)));
      //c2 += "<tr class=\"thin\"><td width=\"6cm\">&nbsp;</td></tr>"; // fixed width
      c2 += "</table>";

      var image = "";
      if (properties.showToolImage) {
        if (i % 2 == 0) {
          toolRenderer.setBackgroundColor(new Color(1, 1, 1));
        } else {
          toolRenderer.setBackgroundColor(new Color(240/255.0, 240/255.0, 240/255.0));
        }
        var path = "tool" + tool.number + ".png";
        var width = 100;
        var height = 133;
        toolRenderer.exportAs(path, "image/png", tool, width, height);
        image = '<img src="' + path + '"/>';
      }
      writeln("");
      
      write(
        makeRow(
          "<td valign=\"top\">" + c1 + "</td>" +
          "<td valign=\"top\">" + c2 + "</td>" +
          "<td class=\"image\" align=\"right\">" + image + "</td>",
          (i % 2 == 0) ? "even" : "odd"
        )
      );
      writeln("");
      writeln("");
    }
  }

  writeln("</table>");
  writeln("");

  write("<br>");
  // write(p(localize("Total number of tools") + ": " + tools.getNumberOfTools()));

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

function onComment(text) {
  if (!comment) {
    comment = text;
  }
}
