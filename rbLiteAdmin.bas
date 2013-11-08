'
'  Project: rbLiteAdmin (http://www.staddle.net)
'  Version: 1.8.10
'  Summary: Run BASIC-based admin tool to manage SQLite databases on the web
'
'  Based On: phpLiteAdmin (http://phpliteadmin.googlecode.com)
'
'  Orginal Developers:
'     Dane Iracleous (daneiracleous@gmail.com)
'     Ian Aldrighetti (ian.aldrighetti@gmail.com)
'     George Flanagin & Digital Gaslight, Inc (george@digitalgaslight.com)
'  
'  Run BASIC port by Neal Collins (ncc@stadddle.net)
'
'  Copyright (C) 2011  phpLiteAdmin
'
'  This program is free software: you can redistribute it and/or modify
'  it under the terms of the GNU General Public License as published by
'  the Free Software Foundation, either version 3 of the License, or
'  (at your option) any later version.
'
'  This program is distributed in the hope that it will be useful,
'  but WITHOUT ANY WARRANTY; without even the implied warranty of
'  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'  GNU General Public License for more details.
'
'  You should have received a copy of the GNU General Public License
'  along with this program.  If not, see <http://www.gnu.org/licenses/>.
'
'//////////////////////////////////////////////////////////////////////////

' please report any bugs you encounter to ncc@staddle.net

' directory relative to this file to search for SQLite databases (if empty, manually list databases below)
directory$ = DefaultDir$

' whether or not (true or false) to scan the subdirectories of the above directory infinitely deep
subdirectories = 0

' if the above directory$ variable is set to false, you must specify the databases manually in an array as the next variable
' if any of the databases do not exist as they are referenced by their path, they will be created automatically if possible

dim databasePaths$(99)
dim databaseNames$(99)

numDatabases = 0

' end of the variables you may need to edit

' build the basename of this file for later reference
' $info = pathinfo($_SERVER['PHP_SELF'])
' $thisName = $info['basename']

' constants
PROJECT$ = "rbLiteAdmin"
VERSION$ = "1.8.10"
PAGE$ = PROJECT$
FORCETYPE = 0 ' force the extension that will be used (set to false in almost all circumstances except debugging)
DELIM$ = chr$(0)
LF$ = chr$(10)
CR$ = chr$(13)

' Row actions array
dim ROWACTS$(1)
ROWACTS$(0) = "Edit"
ROWACTS$(1) = "Delete"

' data types array
dim TYPES$(3)
TYPES$(0) = "INTEGER"
TYPES$(1) = "REAL"
TYPES$(2) = "TEXT"
TYPES$(3) = "BLOB"

' available SQLite functions array
dim FUNCTIONS$(16)
FUNCTIONS$(0) = ""
FUNCTIONS$(1) = "abs"
FUNCTIONS$(2) = "date"
FUNCTIONS$(3) = "datetime"
FUNCTIONS$(4) = "hex"
FUNCTIONS$(5) = "julianday"
FUNCTIONS$(6) = "length"
FUNCTIONS$(7) = "lower"
FUNCTIONS$(8) = "ltrim"
FUNCTIONS$(9) = "random"
FUNCTIONS$(10) = "round"
FUNCTIONS$(11) = "rtrim"
FUNCTIONS$(12) = "soundex"
FUNCTIONS$(13) = "time"
FUNCTIONS$(14) = "trim"
FUNCTIONS$(15) = "typeof"
FUNCTIONS$(16) = "upper"

' Number Operator
dim NUMBEROPS$(7)
NUMBEROPS$(0) = "="
NUMBEROPS$(1) = ">"
NUMBEROPS$(2) = ">="
NUMBEROPS$(3) = "<"
NUMBEROPS$(4) = "<="
NUMBEROPS$(5) = "!="
NUMBEROPS$(6) = "LIKE"
NUMBEROPS$(7) = "NOT LIKE"

' String/Blob Operators
dim STRINGOPS$(3)
STRINGOPS$(0) = "="
STRINGOPS$(1) = "!="
STRINGOPS$(2) = "LIKE"
STRINGOPS$(3) = "NOT LIKE"

' Database/Table View tabs and actions
dim VIEWS$(14)
dim ACTIONS$(14)

VIEWS$(0) = "Structure" : ACTIONS$(0) = "structure"
VIEWS$(1) = "SQL"       : ACTIONS$(1) = "sql"
VIEWS$(2) = "Export"    : ACTIONS$(2) = "export"
VIEWS$(3) = "Import"    : ACTIONS$(3) = "import"
VIEWS$(4) = "Vacuum"    : ACTIONS$(4) = "vacuum"
VIEWS$(5) = "Browse"    : ACTIONS$(5) = "row_view"
VIEWS$(6) = "Structure" : ACTIONS$(6) = "column_view"
VIEWS$(7) = "SQL"       : ACTIONS$(7) = "table_sql"
VIEWS$(8) = "Search"    : ACTIONS$(8) = "table_search"
VIEWS$(9) = "Insert"    : ACTIONS$(9) = "row_create"
VIEWS$(10) = "Export"   : ACTIONS$(10) = "table_export"
VIEWS$(11) = "Import"   : ACTIONS$(11) = "table_import"
VIEWS$(12) = "Rename"   : ACTIONS$(12) = "table_rename"
VIEWS$(13) = "Empty"    : ACTIONS$(13) = "table_empty"
VIEWS$(14) = "Drop"     : ACTIONS$(14) = "table_drop"

startDatabaseViews = 0
endDatabaseViews = 4

startTableViews = 5
endTableViews = 14

dim DUPLICATE$(1)
DUPLICATE$(0) = "Allowed"
DUPLICATE$(1) = "Not Allowed"

dim ORDER$(2)
ORDER$(0) = ""
ORDER$(1) = "Ascending"
ORDER$(2) = "Descending"

' Variables to hold the current database and table
currentDB = -1
tablename$ = ""

' User object
run "userObject", #user

action$ = "structure"

' Setup CSS
call setupCSS

' if the user wants to scan a directory for databases, do so
if directory$ <> "" then
  ' if user has a trailing slash in the directory, remove it
  if right$(directory$, 1) = "/" then directory$ = mid$(directory$, 0, len(directory$)-1)

  files #dir, directory$
  if #dir hasanswer() then
    #dir nextfile$()
    ' make sure the directory is valid
    if #dir isdir() then
      run #dirstack, "stackObject"
      if subdirectories then
        run #searchtree, "stackObject"
        #searchtree push(directory$)
        while #searchtree hasdata()
          dir$ = #searchtree pop$()
          #dirstack push(dir$)
          files #dir, dir$ + "/*"
          while #dir hasanswer()
            #dir nextfile$()
            if #dir isdir() then #searchtree push(dir$ + "/" + #dir name$())
          wend
        wend
      else
        #dirstack push(directory$)
      end if
      j = 0
      while #dirstack hasdata()
        dir$ = #dirstack pop$()
        files #dir, dir$ + "/*"
        for i = 1 to #dir rowcount()
          ' iterate through all the files in the directory
          #dir nextfile$()
          if not(#dir isdir()) then
            file$ = #dir name$()
            if lower$(right$(file$, 3)) = ".db" and file$ <> "Thumbs.db" then
              ' make sure the file is a valid SQLite database by checking its extension
              for k = j to 0 step -1
                if k > 0 then
                  if databaseNames$(k - 1) < file$ then exit for
                  databasePaths$(k) = databasePaths$(k - 1)
                  databaseNames$(k) = databaseNames$(k - 1)
                end if
              next k
              databasePaths$(k) = dir$ + "/" + file$
              databaseNames$(k) = file$
              j = j + 1
            end if
          end if
        next i
      wend
      numDatabases = j
    else ' the directory is not valid - display error and exit
      html "<div class='confirm' style='margin:20px;'>"
      print "The directory you specified to scan for databases is not a directory."
      html "</div>"
      end
    end if
  else
    html "<div class='confirm' style='margin:20px;'>"
    print "The directory you specified to scan for databases does not exist."
    html "</div>"
    end
  end if
end if

'  here begins the HTML.

[start]

' on error goto [runtimeError]

cls
titlebar PROJECT$

head "<script type='text/javascript'>"
' makes sure autoincrement can only be selected when integer type is selected
head "function toggleAutoincrement(i)"
head "{"
head "	var type = document.getElementById('type'+i);"
head "	var autoincrement = document.getElementById('autoincrement'+i);"
head "	if(type.value=='INTEGER')"
head "		autoincrement.disabled = false;"
head "	else"
head "	{"
head "		autoincrement.disabled = true;"
head "		autoincrement.checked = false;"
head "	}"
head "}"

head "function toggleNull(i)"
head "{"
head "	var pk = document.getElementById('primarykey'+i);"
head "	var notnull = document.getElementById('notnull'+i);"
head "	if(pk.checked)"
head "	{"
head "		notnull.disabled = true;"
head "		notnull.checked = true;"
head "	}"
head "	else"
head "	{"
head "		notnull.disabled = false;"
head "	}"
head "}"

' finds and checks all checkboxes for all rows on the Browse or Structure tab for a table
head "function checkAll(field)"
head "{"
head "	var i=0;"
head "	while(document.getElementById('check_'+i)!=undefined)"
head "	{"
head "		document.getElementById('check_'+i).checked = true;"
head "		i++;"
head "	}"
head "}"

' finds and unchecks all checkboxes for all rows on the Browse or Structure tab for a table
head "function uncheckAll(field)"
head "{"
head "	var i=0;"
head "	while(document.getElementById('check_'+i)!=undefined)"
head "	{"
head "		document.getElementById('check_'+i).checked = false;"
head "		i++;"
head "	}"
head "}"

' unchecks the ignore checkbox if user has typed something into one of the fields for adding new rows
head "function changeIgnore(area, e, u)"
head "{"
head "	if(area.value!='')"
head "	{"
head "		if(document.getElementById(e)!=undefined)"
head "			document.getElementById(e).checked = false;"
head "		if(document.getElementById(u)!=undefined)"
head "			document.getElementById(u).checked = false;"
head "	}"
head "}"
' moves fields from select menu into query textarea for SQL tab
head "function moveFields()"
head "{"
head "  var fields = document.getElementById('fieldcontainer');"
head "  var selected = new Array();"
head "	for(var i=0; i<fields.options.length; i++)"
head "		if(fields.options[i].selected)"
head "			selected.push(fields.options[i].value);"
head "	for(var i=0; i<selected.length; i++)"
head "		insertAtCaret('queryval', selected[i]);"
head "}"
' helper function for moveFields
head "function insertAtCaret(areaId,text)"
head "{"
head "	var txtarea = document.getElementById(areaId);"
head "	var scrollPos = txtarea.scrollTop;"
head "	var strPos = 0;"
head "	var br = ((txtarea.selectionStart || txtarea.selectionStart == '0') ? 'ff' : (document.selection ? 'ie' : false ));"
head "	if(br=='ie')"
head "	{"
head "		txtarea.focus();"
head "		var range = document.selection.createRange();"
head "		range.moveStart ('character', -txtarea.value.length);"
head "		strPos = range.text.length;"
head "	}"
head "	else if(br=='ff')"
head "		strPos = txtarea.selectionStart;"
head "	var front = (txtarea.value).substring(0,strPos);"
head "	var back = (txtarea.value).substring(strPos,txtarea.value.length);"
head "	txtarea.value=front+text+back;"
head "	strPos = strPos + text.length;"
head "	if(br=='ie')"
head "	{"
head "		txtarea.focus();"
head "		var range = document.selection.createRange();"
head "		range.moveStart ('character', -txtarea.value.length);"
head "		range.moveStart ('character', strPos);"
head "		range.moveEnd ('character', 0);"
head "		range.select();"
head "	}"
head "	else if(br=='ff')"
head "	{"
head "		txtarea.selectionStart = strPos;"
head "		txtarea.selectionEnd = strPos;"
head "		txtarea.focus();"
head "	}"
head "	txtarea.scrollTop = scrollPos;"
head "}"
' tooltip help feature
head "var tooltip=function()"
head "{"
head "	var id = 'tt';"
head "	var top = 3;"
head "	var left = 3;"
head "	var maxw = 300;"
head "	var speed = 10;"
head "	var timer = 20;"
head "	var endalpha = 95;"
head "	var alpha = 0;"
head "	var tt,t,c,b,h;"
head "	var ie = document.all ? true : false;"
head "	return{"
head "		show:function(v,w)"
head "		{"
head "			if(tt == null)"
head "			{"
head "				tt = document.createElement('div');"
head "				tt.setAttribute('id',id);"
head "				t = document.createElement('div');"
head "				t.setAttribute('id',id + 'top');"
head "				c = document.createElement('div');"
head "				c.setAttribute('id',id + 'cont');"
head "				b = document.createElement('div');"
head "				b.setAttribute('id',id + 'bot');"
head "				tt.appendChild(t);"
head "				tt.appendChild(c);"
head "				tt.appendChild(b);"
head "				document.body.appendChild(tt);"
head "				tt.style.opacity = 0;"
head "				tt.style.filter = 'alpha(opacity=0)';"
head "				document.onmousemove = this.pos;"
head "			}"
head "			tt.style.display = 'block';"
head "			c.innerHTML = v;"
head "			tt.style.width = w ? w + 'px' : 'auto';"
head "			if(!w && ie)"
head "			{"
head "				t.style.display = 'none';"
head "				b.style.display = 'none';"
head "				tt.style.width = tt.offsetWidth;"
head "				t.style.display = 'block';"
head "				b.style.display = 'block';"
head "			}"
head "			if(tt.offsetWidth > maxw)"
head "				tt.style.width = maxw + 'px';"
head "			h = parseInt(tt.offsetHeight) + top;"
head "			clearInterval(tt.timer);"
head "			tt.timer = setInterval(function(){tooltip.fade(1)},timer);"
head "		},"
head "		pos:function(e)"
head "		{"
head "			var u = ie ? event.clientY + document.documentElement.scrollTop : e.pageY;"
head "			var l = ie ? event.clientX + document.documentElement.scrollLeft : e.pageX;"
head "			tt.style.top = (u - h) + 'px';"
head "			tt.style.left = (l + left) + 'px';"
head "		},"
head "		fade:function(d)"
head "		{"
head "			var a = alpha;"
head "			if((a != endalpha && d == 1) || (a != 0 && d == -1))"
head "			{"
head "				var i = speed;"
head "				if(endalpha - a < speed && d == 1)"
head "					i = endalpha - a;"
head "				else if(alpha < speed && d == -1)"
head "					i = a;"
head "				alpha = a + (i * d);"
head "				tt.style.opacity = alpha * .01;"
head "				tt.style.filter = 'alpha(opacity=' + alpha + ')';"
head "			}"
head "			else"
head "			{"
head "				clearInterval(tt.timer);"
head "				if(d == -1)"
head "					tt.style.display = 'none';"
head "			}"
head "		},"
head "		hide:function()"
head "		{"
head "			clearInterval(tt.timer);"
head "			tt.timer = setInterval(function()"
head "			{"
head "				tooltip.fade(-1)"
head "			},timer);"
head "		}"
head "	};"
head "}();"
head "</script>"

if #user id() = 0 then 'user is not authorized - display the login screen
  html "<div id='container'>"
  html "<div id='loginBox'>"
  html "<h1><span id='logo'>";PROJECT$;"</span> <span id='version'>v";VERSION$;"</span></h1>"
  html "<div style='padding:15px; text-align:center;'>"
  if message$ <> "" then html "<span style='color:red;'>" + message$ + "</span><br/><br/>"
  html "Username: "
  textbox #username, username$
  #username setfocus()
  html "<br/>Password: "
  passwordbox #password, ""
  html "<br/>"
  button #login, "Log In", [login]
  #login cssclass("btn")
  html "</div>"
  html "</div>"
  html "<br/>"
  html "<div style='text-align:center;'>"
  html "<span style='font-size:11px;'>Powered by <a href='http://www.staddle.net' target='_blank' style='font-size:11px;'>";PROJECT$;"</a></span>"
  html "</div></div>"
else
  if numDatabases = 0 then ' the database array is empty - show error and halt execution
    html "<div class='confirm' style='margin:20px;'>"
    html "Error: you have not specified any databases to manage."
    html "</div><br/>"
    end
  end if
  ' set the current database to the first in the array (default)
  if currentDB = -1 then currentDB = 0

  html "<div id='container'>"
  html "<div id='leftNav'>"
  html "<h1>"
  html "<span id='logo'>";PROJECT$;"</span> <span id='version'>v";VERSION$;"</span>"
  html "</h1>"
  html "<fieldset style='margin:15px;'><legend><b>Change Database</b></legend>"
  if numDatabases < 10 then
    ' if there aren't a lot of databases, just show them as a list of links instead of drop down menu
    for i = 0 to numDatabases - 1
      link #select, databaseNames$(i), [selectDatabase]
      #select setkey(str$(i))
      if i < numDatabases - 1 then html "<br/>"
    next i
  else
    ' there are a lot of databases - show a drop down menu
    listbox #select, databaseNames$(), 1
    #select select(databaseNames$(currentDB))
    html " "
    button #go, "Go", [selectDatabase]
  end if
  html "</fieldset>"
  html "<fieldset style='margin:15px;'><legend><b>"
  html databaseNames$(currentDB)
  html "</b></legend>"
  ' Display list of tables
  j = 0
  gosub [connect]
  #db execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
  if #db hasanswer() then
    for i = 1 to #db rowcount()
      #row = #db #nextrow()
      name$ = #row name$()
      if left$(name$, 7) <> "sqlite_" and name$ <> "" then
        link #selectTable, name$, [selectTable]
        #selectTable setkey(name$)
        html "<br/>"
        j = j + 1
      end if
    next i
  end if
  gosub [disconnect]
  if j = 0 then html "No tables in database."
  html "</fieldset>"
  html "<div style='text-align:center;'>"
  button #logout, "Log Out", [logout]
  #logout cssclass("btn")
  html "</div>"
  html "</div>"
  html "<div id='content'>"

 ' breadcrumb navigation
  link #link, databaseNames$(currentDB), [changeView2]
  #link setkey("structure")
  if tablename$ <> "" then
    html " &rarr; "
    link #link, tablename$, [changeView]
    #link setkey("row_view")
  end if
  html "<br/><br/>"

  ' show various special views (no tabs)
  select case action$
    case "column_create"
      tablefields = val(#tablefields contents$())
      html "<div id='main'>"
      html "<h2>Adding new field(s) to table '";tablename$;"'</h2>"
      if tablefields = 0 then
        html "You must specify the number of table fields."
      else
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        headings$ = "Field,Type,Autoincrement,Not NULL,Default Value"
        for i = 1 to 5
          html "<td class='tdheader'>";getword$(headings$, i, ",");"</td>"
        next i
        html "</tr>"
        for i = 1 to tablefields
          tdWithClass$ = "<td class='td";i mod 2;"'>"
          html "<tr>"
          html tdWithClass$
          id$ = "field"; i
          textbox #id$, "", 30
          html "</td>"
          html tdWithClass$
          id$ = "type"; i
          listbox #id$, TYPES$(), 1
          html "</td>"
          html tdWithClass$
          id$ = "autoincrement"; i
          checkbox #id$, " Yes", 0
          html "</td>"
          html tdWithClass$
          id$ = "notnull"; i
          checkbox #id$, " Yes", 0
          html "</td>"
          html tdWithClass$
          id$ = "defaultvalue"; i
          textbox #id$, "", 30
          html "</td>"
          html "</tr>"
        next i
        html "<tr>"
        html "<td class='tdheader' style='text-align:right;' colspan='6'>"
        button #create, "Add Field(s)", [addFields]
        #create cssclass("btn")
        html " "
        link #cancel, "Cancel", [cancel]
        html "</td>"
        html "</tr>"
        html "</table>"
      end if
      html "</div>"
      wait
    case "column_delete"
      html "<div id='main'>"
      html "<div class='confirm'>"
      html "Are you sure you want to delete ";countItems(fields$, ",");" columns(s) from table "; tablename$;"?<br/><br/>"
      button #confirmDelete, "Confirm", [deleteFields]
      html " "
      link #cancel, "Cancel", [cancel]
      html "</div>"
      html "</div>"
      wait    
    case "index_delete"
      html "<div id='main'>"
      html "<div class='confirm'>"
      html "Are you sure you want to delete index ";index$;"?<br/><br/>"
      button #confirmDelete, "Confirm", [dropIndex]
      html " "
      link #cancel, "Cancel", [cancel]
      html "</div>"
      html "</div>"
      wait
    case "index_create"
      html "<div id='main'>"
      html "<div class='confirm'>"
      html "<h2>Creating new index on table '"
      print tablename$;
      html "'</h2>"
      if numcolumns < 1 then
        print "You must specify the number of table fields."
      else
        query$ = "PRAGMA table_info(" + tablename$ + ")"
        gosub [connect]
        #db execute(query$)
        dim columns$(#db rowcount())
        columns$(0) = "--Ignore--"
        for i = 1 to #db rowcount()
          row$ = #db nextrow$(",")
          columns$(i) = getword$(row$, 2, ",")
        next i
        gosub [disconnect]
        html "<fieldset><legend>Define index properties</legend>"
        print "Index name: ";
        textbox #index, ""
        print
        print "Duplicate values: ";
        listbox #duplicate, DUPLICATE$(), 1
        print
        html "</fieldset>"
        html "<br/>"
        html "<fieldset><legend>Define index columns</legend>"
        for i = 1 to numcolumns
          id$ = "field_"; i
          listbox #id$, columns$(), 1
          print " ";
          id$ = "option_"; i
          listbox #id$, ORDER$(), 1
          print
        next i
        html "</fieldset>"
        html "<br/><br/>"
        button #create, "Create Index", [createIndex]
        #create cssclass("btn")
        print " ";
        link #cancel, "Cancel", [cancel]
      end if
      html "</div>"
      html "</div>"
      wait
    case "row_delete"
      html "<div id='main'>"
      html "<div class='confirm'>"
      html "Are you sure you want to delete ";countItems(rowids$, ",");" row(s) from table "; tablename$;"?<br/><br/>"
      button #confirmDelete, "Confirm", [deleteRows]
      html " "
      link #cancel, "Cancel", [cancel]
      html "</div>"
      html "</div>"
      wait
    case "row_edit"
      html "<div id='main'>"
      for i = 1 to countItems(rowids$, ",")
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        html "<td class='tdheader'>Field</td>"
        html "<td class='tdheader'>Type</td>"
        html "<td class='tdheader'>Function</td>"
        html "<td class='tdheader'>Null</td>"
        html "<td class='tdheader'>Value</td>"
        html "</tr>"
        query$ = "SELECT * FROM " + tablename$ + " WHERE ROWID = " + getword$(rowids$, i, ",")
        gosub [connect]
        #db execute(query$)
        values$ = #db nextrow$(DELIM$)
        query$ = "PRAGMA table_info(" + tablename$ + ")"
        #db execute(query$)   
        for j = 1 to #db rowcount()
          row$ = #db nextrow$(DELIM$)
          name$ = trim$(getword$(row$, 2, DELIM$))
          type$ = lower$(getword$(row$, 3, DELIM$))
          if type$ = "" then type$ = "null"
          notnull = val(getword$(row$, 4, DELIM$))          
          value$ = getword$(values$, j, DELIM$)
          tdWithClass$ = "<td class='td";j mod 2;"'>"
          tdWithClassLeft$ = "<td class='td";j mod 2;"' style='text-align:left;'>"
          html "<tr>"
          html tdWithClass$
          print name$;
          html "</td>"
          html tdWithClass$
          print type$;
          html "</td>"
          html tdWithClassLeft$
          id$ = "function_";i;"_";name$
          listbox #id$, FUNCTIONS$(), 1
          html "</td>"
          html tdWithClassLeft$
          id$ = "null_";i;"_";name$
          if (type$ <> "text" and value$ = "") then isNull = 1 else isNull = 0
          checkbox #id$, "", isNull
          html "</td>"
          html tdWithClassLeft$
          id$ = "field_";i;"_";name$
          if type$ = "integer" or type$ = "real" or type$ = "null" then
            textbox #id$, value$
          else
            textarea #id$, value$, 60, 5
          end if
          html "</td>"
          html "</tr>"
        next j
        html "<tr>"
        html "<td class='tdheader' style='text-align:right;' colspan='5'>"
        button #save, "Save Changes", [updateRows]
        #save cssclass("btn")
        html " "
        link #cancel, "Cancel", [cancel]
        html "</td>"
        html "</tr>"
        html "</table>"
        html "<br/>"
        gosub [disconnect]
      next i
      html "</div>"
      wait
    case "table_create"
      tablename$ = trim$(#tablename contents$())
      tablefields = val(#tablefields contents$())
      html "<div id='main'>"
      html "<h2>Creating new table: '";tablename$;"'</h2>"
      if tablename$ = "" then
        html "You must specify a table name."
      else
        if tablefields = 0 then
          html "You must specify the number of table fields."
        else
          query$ = "SELECT name FROM sqlite_master WHERE type = 'table' and name = ";quote$(tablename$)
          gosub [connect]
          #db execute(query$)
          if #db rowcount() > 0 then
            html "Table of the same name already exists."
            gosub [disconnect]
          else
            html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
            html "<tr>"
            headings$ = "Field,Type,Primary Key,Autoincrement,Not NULL,Default Value"
            for i = 1 to 6
              html "<td class='tdheader'>";getword$(headings$, i, ",");"</td>"
            next i
            html "</tr>"
            for i = 1 to tablefields
              tdWithClass$ = "<td class='td";i mod 2;"'>"
              html "<tr>"
              html tdWithClass$
              id$ = "field"; i
              textbox #id$, "", 30
              html "</td>"
              html tdWithClass$
              id$ = "type"; i
              listbox #id$, TYPES$(), 1
              html "</td>"
              html tdWithClass$
              id$ = "primarykey"; i
              checkbox #id$, " Yes", 0
              html "</td>"
              html tdWithClass$
              id$ = "autoincrement"; i
              checkbox #id$, " Yes", 0
              html "</td>"
              html tdWithClass$
              id$ = "notnull"; i
              checkbox #id$, " Yes", 0
              html "</td>"
              html tdWithClass$
              id$ = "defaultvalue"; i
              textbox #id$, "", 30
              html "</td>"
              html "</tr>"
            next i
            html "<tr>"
            html "<td class='tdheader' style='text-align:right;' colspan='6'>"
            button #create, "Create", [createTable]
            #create cssclass("btn")
            html " "
            link #cancel, "Cancel", [cancel]
            html "</td>"
            html "</tr>"
            html "</table>"
          end if
        end if
      end if
      html "</div>"
      wait
  end select

  ' show the various tab views
  if tablename$ = "" then
    s = startDatabaseViews
    e = endDatabaseViews
  else
    s = startTableViews
    e = endTableViews
  end if

  for i = s to e
    link #link, VIEWS$(i), [changeView]
    #link setkey(ACTIONS$(i))
    if action$ = ACTIONS$(i) then
      if ACTIONS$(i) = "table_drop" or ACTIONS$(i) = "table_empty" then
        #link cssclass("tab_pressed")
      else
        #link cssclass("tab_pressed")
      end if
    else
      if ACTIONS$(i) = "table_drop" or ACTIONS$(i) = "table_empty" then

        #link cssclass("tab_red") 
      else
        #link cssclass("tab")
      end if
    end if
  next i

  html "<div style='clear:both;'></div>"
  html "<div id='main'>"

 ' user has performed some action so show the resulting message
  if completed$ <> "" then
    html "<div class='confirm'>"
    html completed$
    html "</div>"
    html "<br/>"
    completed$ = ""
  end if

  select case action$
    case "structure"
      query$ = "SELECT sqlite_version() AS version"
      gosub [connect]
      #db execute(query$)
      if #db hasanswer() then
        #row = #db #nextrow()
        realVersion$ = #row version$()
      end if
      gosub [disconnect]
      files #file, databasePaths$(currentDB)
      #file nextfile$()
      #file dateformat("mmm dd, yyyy")
      #file timeformat("hh:mm")
      html "<b>Database name</b>: ";databaseNames$(currentDB);"<br/>"
      html "<b>Path to database</b>: ";databasePaths$(currentDB);"<br/>"
      html "<b>Size of database</b>: ";trim$(using("###,###,###", (#file size() / 1024)));" Kb<br/>"
      html "<b>Database last modified</b>: ";#file time$(); " on ";#file date$();"<br/>"
      html "<b>SQLite version</b>: ";realVersion$;"<br/>"
      html "<b>Platform</b>: ";Platform$;"<br/><br/>"
      query$ = "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
      gosub [connect]
      #db execute(query$)
      if #db hasanswer() then
        j = 0
        dim tables$(#db rowcount() - 1)
        for i = 1 to #db rowcount()
          #row = #db #nextrow()
          name$ = #row name$()
          if left$(name$, 7) <> "sqlite_" and name$ <> "" then
            tables$(j) = name$
            j = j + 1
          end if
        next i
      end if
      gosub [disconnect]
      if j = 0 then
        html "No tables in database.<br/><br/>"
      else
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        html "<td class='tdheader'>Table</td>"
        html "<td class='tdheader' colspan='10'>Action</td>"
        html "<td class='tdheader'>Records</td>"
        html "</tr>"
        totalRecords = 0
        for i = 0 to j - 1
          query$ = "SELECT count(*) AS records FROM " + tables$(i)
          gosub [connect]
          #db execute(query$)
          if #db hasanswer() then
            #row = #db #nextrow()
            records = #row records()
          end if
          gosub [disconnect]
          totalRecords = totalRecords + records
          tdWithClass$ = "<td class='td";(i mod 2);"'>"
          tdWithClassLeft$ = "<td class='td";(i mod 2);"' style='text-align:left;'>"
          html "<tr>"
          html tdWithClassLeft$
          link #link, tables$(i), [changeView2]
          #link setkey("row_view " + tables$(i))
          html "</td>"
          for k = startTableViews to endTableViews
            html tdWithClass$
            link #link, VIEWS$(k), [changeView2]
            #link setkey(ACTIONS$(k) + " " + tables$(i))
            if ACTIONS$(k) = "table_drop" or ACTIONS$(k) = "table_empty" then #link cssclass("red")
            html "</td>"
          next k
          html tdWithClass$
          html records
          html "</td>"
          html "</tr>"
        next i
        html "<tr>"
        html "<td class='tdheader' colspan='11'>";j;" table(s) total</td>"
        html "<td class='tdheader' colspan='1' style='text-align:right;'>";totalRecords;"</td>"
        html "</tr>"
        html "</table>"
      end if
      html "<br/>"
      html "<fieldset>"
      html "<legend><b>Create new table on database '";databaseNames$(currentDB);"'</b></legend>"
      html "Name: "
      textbox #tablename, "", 30
      html " Number of Fields: "
      textbox #tablefields, "", 3
      html " "
      button #go, "Go", [changeView]
      #go setkey("table_create")
      #go cssclass("btn")
      html "</fieldset>"
    case "sql"
      if queryStr$ = "" then delimiter$ = ";"
      html "<fieldset>"
      html "<legend><b>Run SQL query/queries on database '";databaseNames$(currentDB);"'</b></legend>"
      textarea #queryval, queryStr$, 120, 20
      html "<br/>"
      html "Delimiter "
      textbox #delimiter, delimiter$, 1
      html " "
      button #go, "Go", [sql]
      #go cssclass("btn")
      html "</fieldset>"
    case "table_sql"
      if tableQueryStr$ = "" then
        tableQueryStr$ = "SELECT * FROM " + tablename$
        delimiter$ = ";"
      end if
      html "<fieldset>"
      html "<legend><b>Run SQL query/queries on database '";databaseNames$(currentDB);"'</b></legend>"
      html "<div style='float:left; width:70%;'>"
      textarea #queryval, tableQueryStr$, 80, 20
      #queryval setid("queryval")
      html "</div>"
      html "<div style='float:left; width:28%; padding-left:10px;'>"
      html "Fields<br/>"
      html "<select multiple='multiple' style='width:100%;' id='fieldcontainer'>"
      query$ = "PRAGMA table_info(" + tablename$ + ")"
      gosub [connect]
      #db execute(query$)
      while #db hasanswer()
        row$ = #db nextrow$(DELIM$)
        name$ = trim$(getword$(row$, 2, DELIM$))
        html "<option value='" + name$ + "'>" + name$ + "</option>"
      wend
      gosub [disconnect]
      html "</select>"
      html "<input type='button' value='<<' onclick='moveFields();' class='btn'/>"
      html "</div>"
      html "<div style='clear:both;'></div>"
      html "Delimiter "
      textbox #delimiter, delimiter$, 1
      html " "
      button #go, "Go", [tableSql]
      #go cssclass("btn")
      html "</fieldset>"
    case "vacuum"
      html "Large databases sometimes need to be VACUUMed to reduce their footprint on the server. Click the button below to VACUUM the database, '";databaseNames$(currentDB);"'."
      html "<br/><br/>"
      button #vacuum, "VACUUM", [vacuum]
    case "table_empty"
      html "<div class='confirm'>"
      html "Are you sure you want to empty the table '"; tablename$; "'?<br/><br/>"
      button #confirm, "Confirm", [emptyTable]
      #confirm cssclass("btn")
      html " "
      link #cancel, "Cancel", [cancel]
      html "</div>"
    case "export"
      html "<fieldset style='float:left; width:260px; margin-right:20px;'><legend><b>Export</b></legend>"
      listbox #tables, tables$(), 10
      html "<br/><br/>"
      radiogroup #exportType, "SQL", "SQL"
      html "</fieldset>"
      html "<fieldset style='float:left;'><legend><b>Options</b></legend>"
      checkbox #structure, " Export with structure ", 1
      html "[<a onmouseover='tooltip.show(""Creates the queries to add the tables and their columns"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #data, " Export with data ", 1
      html "[<a onmouseover='tooltip.show(""Creates the queries to insert the table rows"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #drop, " Add DROP TABLE ", 0
      html "[<a onmouseover='tooltip.show(""Creates the queries to remove the tables before potentially adding them so that errors do not occur if they already exist"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #transaction, " Add TRANSACTION ", 1
      html "[<a onmouseover='tooltip.show(""Performs queries within transactions so that if an error occurs, the table is not returned to a partially incomplete and unusable state"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #comments, " Comments ", 1
      html "[<a onmouseover='tooltip.show(""Adds comments to the file to explain what is happening in each part of it"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      html "</fieldset>"
      html "<div style='clear:both;'></div>"
      html "<br/><br/>"
      html "<fieldset style='float:left;'><legend><b>Save As</b></legend>"
      textbox #filename, databaseNames$(currentDB) + "." + date$("m-d-yy") + ".dump", 80
      html " "
      button #export, "Export", [export]
      #export cssclass("btn")
      html "</fieldset>"
    case "import"
      html "<fieldset><legend><b>File to import</b></legend>"
      radiogroup #exportType, "SQL", "SQL"
      html "<br/><br/>"
      upload ""; filename$
      if filename$ <> "" then
        open filename$ for input as #file
        filecontents$ = input$(#file, lof(#file))
        close #file
        gosub [connect]
        on error goto [importError]
        for i = 1 to countItems(filecontents$, ";")
          query$ = trim$(removeCRLF$(getword$(filecontents$, i, ";")))
          if query$ <> "" then #db execute(query$)
        next i
        gosub [disconnect]
        completed$ = "Import was successful"
      end if 
      goto [start]
    case "table_drop"
      html "<div class='confirm'>"
      html "Are you sure you want to drop the table '"; tablename$; "'?<br/><br/>"
      button #confirm, "Confirm", [dropTable]
      #confirm cssclass("btn")
      html " "
      link #cancel, "Cancel", [cancel]
      html "</div>"
    case "table_export"
      html "<fieldset style='float:left; width:260px; margin-right:20px;'><legend><b>Export</b></legend>"
      radiogroup #exportType, "SQL", "SQL"
      html "</fieldset>"
      html "<fieldset style='float:left;'><legend><b>Options</b></legend>"
      checkbox #structure, " Export with structure ", 1
      html "[<a onmouseover='tooltip.show(""Creates the queries to add the tables and their columns"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #data, " Export with data ", 1
      html "[<a onmouseover='tooltip.show(""Creates the queries to insert the table rows"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #drop, " Add DROP TABLE ", 0
      html "[<a onmouseover='tooltip.show(""Creates the queries to remove the tables before potentially adding them so that errors do not occur if they already exist"");' onmouseout='tooltip.hide();'>?</a>] <br/>"				
      checkbox #transaction, "Add TRANSACTION", 1
      html "[<a onmouseover='tooltip.show(""Performs queries within transactions so that if an error occurs, the table is not returned to a partially incomplete and unusable state"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      checkbox #comments, " Comments ", 1
      html "[<a onmouseover='tooltip.show(""Adds comments to the file to explain what is happening in each part of it"");' onmouseout='tooltip.hide();'>?</a>]<br/>"
      html "</fieldset>"
      html "<div style='clear:both;'></div>"
      html "<br/><br/>"
      html "<fieldset style='float:left;'><legend><b>Save As</b></legend>"
      textbox #filename, databaseNames$(currentDB) + "." + tablename$ + "." + date$("d-m-yy") + ".dump", 80
      #filename setfocus()
      html " "
      button #export, "Export", [exportTable]
      #export cssclass("btn")
      html "</fieldset>"
    case "table_import"
      html "<fieldset><legend><b>File to import</b></legend>"
      radiogroup #exportType, "SQL", "SQL"
      html "<br/><br/>"
      upload ""; filename$
      if filename$ <> "" then
        open filename$ for input as #file
        filecontents$ = input$(#file, lof(#file))
        close #file
        gosub [connect]
        on error goto [importError]
        for i = 1 to countItems(filecontents$, ";")
          query$ = trim$(removeCRLF$(getword$(filecontents$, i, ";")))
          if query$ <> "" then #db execute(query$)
        next i
        gosub [disconnect]
        completed$ = "Import was successful"
      end if
      goto [start] 
    case "table_rename"
      html "Rename table '"; tablename$; "' to "
      textbox #newname, "", 30
      html " "
      button #rename, "Rename", [renameTable]
      #rename cssclass("btn")
    case "table_search"
      html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
      html "<tr>"
      html "<td class='tdheader'>Field</td>"
      html "<td class='tdheader'>Type</td>"
      html "<td class='tdheader'>Operator</td>"
      html "<td class='tdheader'>Value</td>"
      html "</tr>"
      query$ = "PRAGMA table_info(" + quote$(tablename$) + ")"
      gosub [connect]
      #db execute(query$)
      while #db hasanswer()
        row$ = #db nextrow$(DELIM$)
        name$ = getword$(row$, 2, DELIM$)
        type$ = lower$(getword$(row$, 3, DELIM$))
        if type$ = "" then type$ = "null"
        tdWithClass$ = "<td class='td";i mod 2;"'>"
        tdWithClassLeft$ = "<td class='td";i mod 2;"' style='text-align:left;'>"
        html "<tr>"
        html tdWithClassLeft$
        print name$;
        html "</td>"
        html tdWithClassLeft$
        print type$;
        html "</td>"
        html tdWithClassLeft$
        id$ = "operator_";name$
        if type$ = "integer" or type$ = "real" then
          listbox #id$, NUMBEROPS$(), 1
        else
          listbox #id$, STRINGOPS$(), 1
        end if
        #id$ select("=")
        html "</td>"
        html tdWithClassLeft$
        id$ = "field_" + name$
        if type$ = "integer" or type$ = "real" or type$ = "null" then
          textbox #id$, ""
        else
          textarea #id$, "", 60, 1
        end if
        html "</td>"
        html "</tr>"   
      wend
      gosub [disconnect]
      html "<tr>"
      html "<td class='tdheader' style='text-align:right;' colspan='4'>"
      button #search, "Search", [searchTable]
      #search cssclass("btn")
      html "</td>"
      html "</tr>"
      html "</table>"
    case "search_results"
      gosub [connect]
      on error goto [searchError]
      #db execute(searchQuery$)
      html "<div class='confirm'>"
      print "Showing "; #db rowcount(); " affected row(s).";      
      html "<br/><span style='font-size:11px;'>"
      print queryDisplay$;
      html "</span>"
      html "</div><br/>"
      if #db rowcount() > 0 then
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        html "<td colspan='2'>&nbsp;</td>"
        headers$ = #db columnnames$()
        for j = 2 to countItems(headers$, ",")
          html "<td class='tdheader'>"
          print trim$(getword$(headers$, j, ","))
          html "</td>"
        next j
        html "</tr>"
        for i = 0 to #db rowcount() - 1
          row$ = #db nextrow$(DELIM$)
	  ' rowid will always be the first column in each row
	  rowid$ = getword$(row$, 1, DELIM$)
          tdWithClass$ = "<td class='td";i mod 2;"'>"
          html "<tr>"
	  html tdWithClass$
	  link #edit, "Edit", [edit]
	  #edit setkey(rowid$)
	  html "</td>"
	  html tdWithClass$
	  link #delete, "delete", [deleteRow]
	  #delete setkey(rowid$)
	  #delete cssclass("red")
	  html "</td>"
          for j = 2 to countItems(headers$, ",")
            html tdWithClass$
            print getword$(row$, j, DELIM$)
            html "</td>"
          next j
          html "</tr>"
        next i
        html "</table><br/><br/>"
      end if
      link #search, "Do Another Search", [newSearch]
    case "row_view"
      startRow = max(startRow, 1)
      if numRows = 0 then numRows = 30
      query$ = "SELECT count(*) FROM " + tablename$
      gosub [connect]
      #db execute(query$)
      rowCount = val(#db nextrow$())
      gosub [disconnect]
      lastPage = int(rowCount / numRows)
      remainder = rowCount MOD numRows
      if remainder = 0 then remainder = numRows
      html "<div style='overflow:hidden;'>"
      ' previous button
      if startRow > 1 then
        html "<div style='float:left; overflow:hidden;'>"
        button #first, "<<", [setRow]
        #first setkey("0")
        #first cssclass("btn")
        html "</div>"
        html "<div style='float:left; overflow:hidden; margin-right:20px;'>"
        button #previous, "<", [setRow]
        #previous setkey(str$(startRow - numRows))
        html "</div>"
      end if
      ' show certain number buttons
      html "<div style='float:left; overflow:hidden;'>"
      button #show, "Show : ", [show]
      #show cssclass("btn")
      html " "
      textbox #numRows, str$(numRows), 4
      html " row(s) starting from record # "
      textbox #startRow, str$(startRow), 4
      html "</div>"
      if startRow + numRows < rowCount then
        html "<div style='float:left; overflow:hidden; margin-left:20px; '>"
        button #next, ">", [setRow]
        #next setkey(str$(startRow + numRows))
        #next cssclass("btn")
        html "</div>"
        html "<div style='float:left; overflow:hidden;'>"
        button #last, ">>", [setRow]
        #last setkey(str$(rowCount - remainder + 1))
        #last cssclass("btn")
        html "</div>"
      end if
      html "<div style='clear:both;'></div>"
      html "</div>"
      query$ = "SELECT ROWID, * FROM " + tablename$
      queryDisp$ = "SELECT * FROM " + tablename$
      queryAdd$ = ""
      if sortField$ <> "" then queryAdd$ = queryAdd$ + " ORDER BY " + sortField$
      if order$ <> "" then queryAdd$ = queryAdd$ + " "+ order$
      queryAdd$ = queryAdd$ + " LIMIT " + str$(startRow - 1) + ", " + str$(numRows)
      query$ = query$ + queryAdd$
      queryDisp$ = queryDisp$ + queryAdd$
      gosub [connect]
      #db execute("SELECT COUNT(*) FROM "; tablename$)
      total = val(#db nextrow$())
      if total > 0 then
        #db execute(query$)
        if #db rowcount() > 0 then
          html "<br/><div class='confirm'>"
          html "<b>Showing rows ";startRow;" - ";(startRow + #db rowcount() - 1);" (";total;" total)</b><br/>"
          html "<span style='font-size:11px;'>";queryDisp$;"</span>"
          html "</div><br/>"
          html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
          html "<tr>"
          html "<td colspan='3'>&nbsp;</td>"
          numColumns = countItems(#db columnnames$(), ",")
          for i = 2 to numColumns
            html "<td class='tdheader'>"
            column$ = trim$(getword$(#db columnnames$(), i, ","))
            if column$ = sortField$ and order$ = "ASC" then orderTag$ = "DESC" else orderTag$ = "ASC"
            link #link, column$, [changeSort]
            #link setkey(column$ + " " + orderTag$)
            html "</td>"
          next i
          html "</tr>"
          rowCount = #db rowcount()
          dim rowidArray$(rowCount)
          for i = 0 to rowCount - 1
            row$ = #db nextrow$(DELIM$)
            ' rowid will always be the first column in each row
            rowidArray$(i) = getword$(row$, 1, DELIM$)
            tdWithClass$ = "<td class='td";i mod 2;"'>"
            tdWithClassLeft$ = "<td class='td";i mod 2;"' style='text-align:left;'>"
            html "<tr>"
            html tdWithClass$
            id$ = "check_"; i
            checkbox #id$, "", 0
            #id$ setid(id$)
            html "</td>"
            html tdWithClass$
            link #edit, "Edit", [edit]
            #edit setkey(rowidArray$(i))
            html "</td>"
            html tdWithClass$
            link #delete, "delete", [deleteRow]
            #delete setkey(rowidArray$(i))
            #delete cssclass("red")
            html "</td>"
            for j = 2 to numColumns
              html tdWithClassLeft$
              columnValue$ = getword$(row$, j, DELIM$)
              if columnValue$ = "" then html "<i>NULL</i>" else print columnValue$;
              html "</td>"
            next j
            html "</tr>"
          next i
          html "</table>"
          html "<a onclick='checkAll()'>Check All</a> / <a onclick='uncheckAll()'>Uncheck All</a> "
          html "<i>With selected:</i> "
          listbox #rowAction, ROWACTS$(), 1
          html " "
          button #go, "Go", [multiRows]
          #go cssclass("btn")
        else
          html "<br/><br/>There are no rows in the table for the range you selected."
        end if
      else
        html "<br/><br/>This table is empty. "
        link #insert, "Click here", [changeView]
        #insert setkey("row_create")
        html " to insert rows."
      end if
      gosub [disconnect]
    case "column_view"
      html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
      html "<tr>"
      html "<td class='tdheader'>Column #</td>"
      html "<td class='tdheader'>Field</td>"
      html "<td class='tdheader'>Type</td>"
      html "<td class='tdheader'>Not Null</td>"
      html "<td class='tdheader'>Default Value</td>"
      html "<td class='tdheader'>Primary Key</td>"
      html "</tr>"
      query$ = "PRAGMA table_info(" + quote$(tablename$) + ")"
      gosub [connect]
      #db execute(query$)
      numFields = #db rowcount()
      for i = 1 to numFields
        row$ = #db nextrow$(DELIM$)
        colVal$ = getword$(row$, 1, DELIM$)
        fieldVal$ = trim$(getword$(row$, 2, DELIM$))
        typeVal$ = lower$(getword$(row$, 3, DELIM$))
        if getword$(row$, 4, DELIM$) <> "0" then notnullVal$ = "yes" else notnullVal$ = "no"
        defaultVal$ = getword$(row$, 5, DELIM$)
        if getword$(row$, 6, DELIM$) <> "0" then primarykeyVal$ = "yes" else primarykeyVal$ = "no"

        tdWithClass$ = "<td class='td";i mod 2;"'>"
        tdWithClassLeft$ = "<td class='td";i mod 2;"' style='text-align:left;'>"
        html "<tr>"
        html tdWithClass$;colVal$;"</td>"
        html tdWithClassLeft$;fieldVal$;"</td>"
        html tdWithClassLeft$;typeVal$;"</td>"
        html tdWithClassLeft$;notnullVal$;"</td>"
        html tdWithClassLeft$
        print defaultVal$;
        html "</td>"
        html tdWithClassLeft$;primarykeyVal$;"</td>"
        html "</tr>"
      next i
      gosub [disconnect]
      html "</table>"
      html "<br/>"
      html "Add "
      textbox #tablefields, "1", 4
      html " field(s) at end of the table "
      button #go, "Go", [changeView]
      #go setkey("column_create")
      #go cssclass("btn")
      html "<br/><hr/><br/>"
      query$ = "PRAGMA index_list(";quote$(tablename$);")"
      gosub [connect]
      #db execute(query$)
      if #db hasanswer() then
        html "<h2>Indexes:</h2>"
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        html "<td colspan='1'>"
        html "</td>"
        html "<td class='tdheader'>Name</td>"
        html "<td class='tdheader'>Unique</td>"
        html "<td class='tdheader'>Seq. No.</td>"
        html "<td class='tdheader'>Column #</td>"
        html "<td class='tdheader'>Field</td>"
        html "</tr>"
        for i = 1 to #db rowcount()
          #row = #db #nextrow()
          seqVal = #row seq()
          nameVal$ = #row name$()
          if #row unique() = 0 then uniqueVal$ = "no" else uniqueVal$ = "yes"

          tdWithClass$ = "<td class='td";i mod 2;"'>"           
          tdWithClassLeft$ = "<td class='td";i mod 2;"' style='text-align:left;'>"
          tdWithClassSpan$ = "<td class='td";i mod 2;"' rowspan='3'>"
          tdWithClassLeftSpan$ = "<td class='td";i mod 2;"' style='text-align:left;' rowspan='3'>"
          html "<tr>"
          html tdWithClassSpan$
          link #delete, "delete", [deleteIndex]
          #delete setkey(nameVal$)
          #delete cssclass("red")
          html "</td>"
          html tdWithClassLeftSpan$;nameVal$;"</td>"
          html tdWithClassLeftSpan$;uniqueVal$;"</td>"

          query$ = "PRAGMA index_info("; quote$(nameVal$); ")"
          gosub [connect2]
          #db2 execute(query$)
          for j = 1 to #db2 rowcount()
            #row2 = #db2 #nextrow()
            if j <> 1 then html "<tr>"
            html tdWithClassLeft$;#row2 seqno();"</td>"
            html tdWithClassLeft$;#row2 cid();"</td>"
            html tdWithClassLeft$;#row2 name$();"</td>"
            html "</tr>"
          next j
          gosub [disconnect2]
        next i
        html "</table>"
      end if
      gosub [disconnect]
      html "<br/><div class='tdheader'>"
      html "Create an index on "
      textbox #numcolumns, "1", 4
      html " columns "
      button #go, "Go", [addIndex]
      #go cssclass("btn")
    case "row_create"
      insertRows = max(insertRows, 1)
      ' html "<div id='main'>"
      html "Restart insertion with "
      dim rows$(39)
      for i = 1 to 40
        rows$(i - 1) = str$(i)
      next i
      listbox #insertRows, rows$(), 1
      #insertRows select(str$(insertRows))
      html " rows "
      button #go, "Go", [changeInsertRows]
      html "<br/>"
      for j = 0 to insertRows - 1
        if j > 0 then
          id$ = j;"_ignore"
          checkbox #id$, "Ignore", 0
          html "<br/>"
        end if
        html "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        html "<tr>"
        html "<td class='tdheader'>Field</td>"
        html "<td class='tdheader'>Type</td>"
        html "<td class='tdheader'>Function</td>"
        html "<td class='tdheader'>Null</td>"
        html "<td class='tdheader'>Value</td>"
        html "</tr>"

        query$ = "PRAGMA table_info(" + tablename$ + ")"
        gosub [connect]
        #db execute(query$)
        for i = 1 to #db rowcount()
          row$ = #db nextrow$(DELIM$)
          name$ = trim$(getword$(row$, 2, DELIM$))
          type$ = lower$(getword$(row$, 3, DELIM$))
          if type$ = "" then type$ = "null"
          notnull = val(getword$(row$, 4, DELIM$))
          default$ = dequote$(getword$(row$, 5, DELIM$))
          tdWithClass$ = "<td class='td";i mod 2;"'>"
          tdWithClassLeft$ = "<td class='td";i mod 2;"' style='text-align:left;'>"
          html "<tr>"
          html tdWithClassLeft$
          print name$;
          html "</td>"
          html tdWithClassLeft$
          print type$;
          html "</td>"
          html tdWithClassLeft$
          id$ = "function_";j;"_";name$
          listbox #id$, FUNCTIONS$(), 1
          html "</td>"
          html tdWithClassLeft$
          if not(notnull) then
            id$ = "null_";j;"_";name$
            checkbox #id$, "", 0
          end if
          html "</td>"
          html tdWithClassLeft$
          id$ = "field_";j;"_";name$
          if type$ = "integer" or type$ = "real" or type$ = "null" then
            textbox #id$, default$
          else
            textarea #id$, default$, 60, 5
          end if
          html "</td>"
          html "</tr>"
        next i
        gosub [disconnect]
        html "<tr>"
        html "<td class='tdheader' style='text-align:right;' colspan='5'>"
        button #insert, "Insert", [createRows]
        #insert cssclass("btn")
        html "</td>"
        html "</tr>"
        html "</table><br/>"
      next j
      ' html "</div>"
  end select
  html "</div>"
  html "<br/>"
  html "<span style='font-size:11px;'>Powered by <a href='http://www.staddle.net/' target='_blank' style='font-size:11px;'>";PROJECT$;"</a></span>"
  html "</div>"
  html "</div>"
end if

wait

' Subroutines

[addFields]
  for i = 1 to tablefields
    id$ = "field"; i
    if #id$ contents$() <> "" then
      query$ = "ALTER TABLE " + tablename$ + " ADD COLUMN " + #id$ contents$()
      id$ = "type"; i
      query$ = query$ + " " + #id$ selection$()
      id$ = "notnull"; i
      if #id$ value() then query$ = query$ + " NOT NULL"
      id$ = "defaultvalue"; i
      if #id$ contents$() <> "" then
        query$ = query$ + " DEFAULT " + quote$(#id$ contents$())
      end if
      gosub [connect]
      #db execute(query$)
      gosub [disconnect]
    end if
  next i
  completed$ = "Table " + tablename$ + " has been altered successfully."
  action$ = "row_view"
  goto [start]

[addIndex]
  action$ = "index_create"
  numcolumns = val(#numcolumns contents$())
  goto [start]

[cancel]
  if tablename$ = "" or action$ = "table_create" then
    action$ = "structure"
    tablename$ = ""
  else
    if nextAction$ = "" then
      action$ = "row_view"
    else
      action$ = nextAction$
      nextAction$ = ""
    end if
  end if
  goto [start]

[changeInsertRows]
  insertRows = val(#insertRows selection$())
  goto [start]

[changeSort]
  sortField$ = word$(EventKey$, 1)
  order$ = word$(EventKey$, 2)
  goto [start]

[changeView]
  action$ = EventKey$
  goto [start]

[changeView2]
  action$ = word$(EventKey$, 1)
  tablename$ = word$(EventKey$, 2)
  goto [start]

[connect]
  sqliteconnect #db, databasePaths$(currentDB)
  return

[connect2]
  sqliteconnect #db2, databasePaths$(currentDB)
  return

[createRows]
  for j = 0 to insertRows - 1
    if j > 0 then
      ' Ignore checkbox
      id$ = j;"_ignore"
      ignore = #id$ value()
    else
      ignore = 0
    end if
    if not(ignore) then
      columns$ = ""
      values$ = ""
      query$ = "PRAGMA table_info(" + tablename$ + ")"
      gosub [connect]
      #db execute(query$)
      for i = 1 to #db rowcount()
        row$ = #db nextrow$(DELIM$)
        name$ = trim$(getword$(row$, 2, DELIM$))
        type$ = lower$(getword$(row$, 3, DELIM$))
        notnull = val(getword$(row$, 4, DELIM$))
        
        ' Function
        id$ = "function_";j;"_";name$
        f$ = #id$ selection$()

        if notnull = 0 then
          id$ = "null_";j;"_";name$
          null = #id$ value()
        end if

        ' Value
        id$ = "field_";j;"_";name$
        value$ = #id$ contents$()

        ' Build insert statement
        columns$ = columns$ + "," + name$
        values$ = values$ + "," 
        if f$ <> "" then values$ = values$ + f$ + "("
        if null or (type$ <> "text" and value$ = "") then
          values$ = values$ + "NULL"
        else
          values$ = values$ + quote$(value$)
        end if
        if f$ <> "" then values$ = values$ + ")"
      next i
      query$ = "insert into " + tablename$ + "(" + mid$(columns$, 2) + ") values (" + mid$(values$, 2) + ")"
      on error goto [createError]
      #db execute(query$)
      completed$ = completed$ + "<span style='font-size:11px;'>" + query$ + "</span><br/>"
      gosub [disconnect]
    end if
  next j   
  action$ = "row_view"
  goto [start]

[createError]
  gosub [disconnect]
  completed$ = completed$ + "<b>There is a problem with the following insert statement:</b><br/>"
  completed$ = completed$ + "<span style='font-size:11px;'>" + query$ + "</span><br/>"
  action$ = "row_view"
  goto [start]

[createIndex]
  index$ = trim$(#index contents$())
  if index$ = "" then
    completed$ = "Index name must not be blank."
    action$ = "column_view"
    goto [start]
  end if
  query$ = "CREATE "
  if #duplicate selection$() = "Not Allowed" then query$ = query$ + "UNIQUE "
  query$ = query$ + "INDEX " + index$ + " ON " + tablename$ + "("
  id$ = "field_1"
  if #id$ selection$() = "--Ignore--" then
    completed$ = "You must specify at least one index column."
    action$ = "column_view"
    goto [start]
  end if
  query$ = query$ + #id$ selection$()
  id$ = "option_1"
  select case #id$ selection$()
    case "Ascending"
      query$ = query$ + " ASC"
    case "Descending"
      query$ = query$ + " DESC"
  end select
  for i = 2 to numcolumns
    id$ = "field_"; i
    if #id$ selection$() <> "--Ignore--" then
      query$ = query$ + ", " + #id$ selection$()
      id$ = "option_"; i
      select case #id$ selection$()
        case "Ascending"
          query$ = query$ + " ASC"
        case "Descending"
          query$ = query$ + " DESC"
      end select
    end if
  next i
  query$ = query$ + ")"
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "Index created.<br/><span style='font-size:11px;'>" + query$ + "</span>"
  action$ = "column_view"
  goto [start]

[createTable]
  query$ = "CREATE TABLE " + tablename$ + "("
  primarykeys$ = ""
  for i = 1 to tablefields
    id$ = "field"; i
    if #id$ contents$() <> "" then
      colname$ = #id$ contents$()
      query$ = query$ + colname$
      id$ = "type"; i
      query$ = query$ + " " + #id$ selection$()
      id$ = "autoincrement"; i
      if #id$ value() then
        ' Autoincrement implies primary key
        query$ = query$ + " PRIMARY KEY AUTOINCREMENT"
      else
        id$ = "primarykey"; i
        if #id$ value() then
          if primarykeys$ <> "" then primarykeys$ = primarykeys$ + ","
          primarykeys$ = primarykeys$ + colname$
        end if
      end if
      id$ = "notnull"; i
      if #id$ value() then query$ = query$ + " NOT NULL"
      id$ = "defaultvalue"; i
      if #id$ contents$() <> "" then
        query$ = query$ + " DEFAULT " + quote$(#id$ contents$())
      end if
      query$ = query$ + ", "
    end if
  next i
  if primarykeys$ <> "" then
    query$ = query$ + "PRIMARY KEY (" + primarykeys$ + "), "
  end if
  query$ = left$(query$, len(query$) - 2) + ")"
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "Table " + tablename$ + " has been created.<br/><span style='font-size:11px;'>" + query$ + "</span>"
  action$ = "row_view"
  goto [start]

[deleteIndex]
  action$ = "index_delete"
  index$ = EventKey$
  goto [start]

[deleteRow]
  nextAction$ = action$
  action$ = "row_delete"
  rowids$ = EventKey$
  goto [start]

[deleteRows]
  query$ = "DELETE FROM " + tablename$ + " WHERE ROWID IN (" + rowids$ + ")"
  gosub [connect]
  #db execute(query$)
  #db execute("SELECT changes() AS changes")
  #row = #db #nextrow()
  completed$ = #row changes();" rows deleted.<br/><span style='font-size:11px;'>";query$;"</span>"
  gosub [disconnect]
  if nextAction$ = "" then
    action$ = "row_view"
  else
    action$ = nextAction$
    nextAction$ = ""
  end if
  goto [start]

[disconnect]
  #db disconnect()
  return

[disconnect2]
  #db2 disconnect()
  return

[dropIndex]
  query$ = "DROP INDEX " + index$
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "Index '" + tablename$ + "' deleted.<br/><span style='font-size:11px;'>" + query$ + "</span>"
  action$ = "column_view"
  goto [start]

[dropTable]
  query$ = "DROP TABLE " + tablename$
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "Table " + tablename$ + " has been dropped."
  tablename$ = ""
  action$ = "structure"
  goto [start]

[edit]
  nextAction$ = action$
  action$ = "row_edit"
  rowids$ = EventKey$
  goto [start]

[emptyTable]
  query$ = "DELETE FROM " + tablename$
  gosub [connect]
  #db execute(query$)
  #db execute("VACUUM")
  gosub [disconnect]
  completed$ = "Table " + tablename$ + " has been emptied.<br/><span style='font-size:11px;'>" + query$ + "</span>"
  action$ = "row_view"
  goto [start]

[export]
  comments = #comments value()
  exportData = #data value()
  drop = #drop value()
  structure = #structure value()
  filename$ = #filename contents$()
  filepath$ = ResourcesRoot$ + "/" + filename$
  open filepath$ for output as #dump
  if comments then
    print #dump, "----"
    print #dump, "-- rbLiteAdmin database dump (http://www.staddle.net)"
    print #dump, "-- rbLiteAdmin version: ";VERSION$
    print #dump, "-- Exported on ";date$("mmm dd, yyyy");", ";time$()
    print #dump, "-- Database file: ";databasePaths$(currentDB)
    print #dump, "----"
  end if
  query$ = "SELECT type, name, tbl_name AS tableName, sql FROM sqlite_master WHERE type='table' OR type='index' ORDER BY type DESC"
  gosub [connect]
  #db execute(query$)
  if #db hasanswer() then
    for i = 1 to #db rowcount()
      #row = #db #nextrow()
      type$ = #row type$()
      name$ = #row name$()
      tableName$ = #row tableName$()
      sql$ = #row sql$()
      if drop then
        if comments then
          print #dump, "----"
          print #dump, "-- Drop ";type$;" for ";name$
          print #dump, "----"
        end if
        print #dump, "DROP ";upper$(type$);" ";name$;";"
      end if
      if structure then
        if comments then
          print #dump, "----"
          if type$ = "table" then
            print #dump, "-- Table structure for ";name$
          else
            print #dump, "-- Structure for index ";name$;" on table ";tableName$
          end if
          print #dump, "----"
        end if
        print #dump, sql$;";"
      end if
      if exportData and type$ = "table" then
        query$ = "SELECT * FROM " + name$
        gosub [connect2]
        #db2 execute(query$)
        if #db2 hasanswer() then
          if comments then
            print #dump, "----"
            print #dump, "Data dump for ";name$;", a total of ";#db2 rowcount();" rows"
            print #dump, "----"
          end if
          for j = 1 to #db2 rowcount()
            row$ = #db2 nextrow$(DELIM$)
            print #dump, "INSERT INTO ";name$;"(";#db2 columnnames$();") VALUES (";
            for k = 1 to countItems(#db2 columnnames$(), ",")
              if k <> 1 then print #dump, ",";
              print #dump, quote$(getword$(row$, k, DELIM$));
            next k
            print #dump, ");"
          next j
        end if
        gosub [disconnect2]
      end if
    next i
  end if
  close #dump
  completed$ = "Export completed. Click <a href='/" + filename$ + "'>here</a> to download dump file."
  goto [start]

[exportTable]
  comments = #comments value()
  exportData = #data value()
  drop = #drop value()
  structure = #structure value()
  filename$ = #filename contents$()
  filepath$ = ResourcesRoot$ + "/" + filename$
  open filepath$ for output as #dump
  if comments then
    print #dump, "----"
    print #dump, "-- rbLiteAdmin database dump (http://www.staddle.net)"
    print #dump, "-- rbLiteAdmin version: ";VERSION$
    print #dump, "-- Exported on ";date$("mmm dd, yyyy");", ";time$()
    print #dump, "-- Database file: ";databasePaths$(currentDB)
    print #dump, "----"
  end if
  query$ = "SELECT type, name, tbl_name AS tableName, sql FROM sqlite_master WHERE (type='table' OR type='index') AND tbl_name = " + quote$(tablename$)
  gosub [connect]
  #db execute(query$)
  if #db hasanswer() then
    for i = 1 to #db rowcount()
      #row = #db #nextrow()
      type$ = #row type$()
      name$ = #row name$()
      tableName$ = #row tableName$()
      sql$ = #row sql$()
      if drop then
        if comments then
          print #dump, "----"
          print #dump, "-- Drop ";type$;" for ";name$
          print #dump, "----"
        end if
        print #dump, "DROP ";upper$(type$);" ";name$;";"
      end if
      if structure then
        if comments then
          print #dump, "----"
          if type$ = "table" then
            print #dump, "-- Table structure for ";name$
          else
            print #dump, "-- Structure for index ";name$;" on table ";tableName$
          end if
          print #dump, "----"
        end if
        print #dump, sql$;";"
      end if
      if exportData and type$ = "table" then
        query$ = "SELECT * FROM " + name$
        gosub [connect2]
        #db2 execute(query$)
        if #db2 hasanswer() then
          if comments then
            print #dump, "----"
            print #dump, "Data dump for ";name$;", a total of ";#db2 rowcount();" rows"
            print #dump, "----"
          end if
          for j = 1 to #db2 rowcount()
            row$ = #db2 nextrow$(DELIM$)
            print #dump, "INSERT INTO ";name$;"(";#db2 columnnames$();") VALUES (";
            for k = 1 to countItems(#db2 columnnames$(), ",")
              if k <> 1 then print #dump, ",";
              print #dump, quote$(getword$(row$, k, DELIM$));
            next k
            print #dump, ");"
          next j
        end if
        gosub [disconnect2]
      end if
    next i
  end if
  close #dump
  completed$ = "Export completed. Click <a href='/" + filename$ + "'>here</a> to download dump file."
  goto [start]

[importError]
  gosub [disconnect]
  completed$ = "<b>Import has failed</b><br/><span style='font-size:11px;'>" + query$ + "</span>"
  goto [start]

[login]
  ' user has attempted to log in
  ' make sure passwords match before granting authorization
  username$ = lower$(#username contents$())
  password$ = #password contents$()

  userId = #user login(username$, password$)

  message$ = ""
  if userId = 0 then
    message$ = #user errorMessage$()
    goto [start]
  end if

  if username$ <> "ncc" then
    #user logout()
    message$ = "You are not authorised to use this program."
    goto [start]
  end if

  goto [start]

[logout]
  ' user has attempted to log out
  #user logout()
  expire "/"

[multiFields]
  fields$ = ""
  for i = 0 to numFields - 1
    id$ = "check_"; i
    if #id$ value() then fields$ = fields$ + "," + fieldVal$(i)
  next i
  if fields$ = "" then
    completed$ = "Error: You did not select anything."
    goto [start]
  end if
  fields$ = mid$(fields$, 2) ' strip leading ","
  action$ = "column_" + lower$(#rowAction selection$())
  goto [start]

[multiRows]
  rowids$ = ""
  for i = 0 to rowCount - 1
    id$ = "check_"; i
    if #id$ value() then rowids$ = rowids$ + "," + rowidArray$(i)
  next i
  if rowids$ = "" then
    completed$ = "Error: You did not select anything."
    goto [start]
  end if
  rowids$ = mid$(rowids$, 2) ' strip leading ","
  action$ = "row_" + lower$(#rowAction selection$())
  goto [start]

[newSearch]
  action$ = "table_search"
  goto [start]

[renameTable]
  newname$ = #newname contents$()
  if newname$ = "" then
    completed$ = "Error: You did not enter a new table name."
    goto [start]
  end if
  query$ = "ALTER TABLE " + tablename$ + " RENAME TO " + newname$
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "Table " + tablename$ + "has been renamed to " + newname$ + ".<br/><span style='font-size:11px;'>" + query$ + "</span>"
  tablename$ = ""
  action$ = "structure"
  goto [start]

[runtimeError]
  completed$ = completed$ + "<b>There has been an unexpected error: " + err$ + " (" + str$(err) + ")</b><br/>"
  action$ = "row_view"
  goto [start]

[searchError]
  gosub [disconnect]
  completed$ = completed$ + "<b>There was an error in the search query</b><br/><span style='font-size:11px;'>" + searchQuery$ + "</span>"
  searchQuery$ = ""
  goto [start]

[searchTable]
  query$ = "PRAGMA table_info(" + quote$(tablename$) + ")"
  gosub [connect]
  #db execute(query$)
  where$ = ""
  while #db hasanswer()
    row$ = #db nextrow$(DELIM$)
    name$ = getword$(row$, 2, DELIM$)
    type$ = lower$(getword$(row$, 3, DELIM$))
    if type$ = "" then type$ = "null"
    ' Operator
    id$ = "operator_";name$
    operator$ = #id$ selection$()
    ' Value
    id$ = "field_" + name$
    value$ = #id$ contents$()
    ' Build query
    if value$ <> "" then
      where$ = where$ + " AND " + name$ + " " + operator$ + " " + quote$(value$)
    end if
  wend
  searchQuery$ = "SELECT ROWID,* FROM " + tablename$
  queryDisplay$ = "SELECT * FROM " + tablename$
  if mid$(where$, 6) <> "" then 
    searchQuery$ = searchQuery$ + " WHERE " + mid$(where$, 6)
    queryDisplay$ = queryDisplay$ + " WHERE " + mid$(where$, 6)
  end if
  gosub [disconnect]
  action$ = "search_results"
  goto [start]

[selectDatabase]
  if EventKey$ = "#go" then
    for i = 0 to numDatabases - 1
      if #select selection$() = databaseNames$(i) then
        currentDB = i
        exit for
      end if
    next i
  else
    currentDB = val(EventKey$)
  end if
  action$ = "structure"
  tablename$ = ""
  goto [start]

[selectTable]
  tablename$ = EventKey$
  action$ = "row_view"
  startRow = 0
  numRows = 0
  sortField$ = ""
  order$ = ""
  tableQuery$ = ""
  goto [start]

[setRow]
  startRow = val(EventKey$)
  goto [start]

[show]
  startRow = val(#startRow contents$())
  numRows = val(#numRows contents$())
  goto [start]

[sql]
  queryStr$ = #queryval contents$()
  delimiter$ = #delimiter contents$()
  for i = 1 to countSql(queryStr$, delimiter$)
    ' iterate through the queries exploded by the delimiter
    query$ = trim$(removeCRLF$(getsql$(queryStr$, i, delimiter$)))
    if query$ <> "" then
      if left$(lower$(query$), 6) = "select" then isSelect = 1 else isSelect = 0
      gosub [connect]
      on error goto [sqlError]
      #db execute(query$)
      if isSelect and #db hasanswer() then
        completed$ = completed$ + "<b>Showing "; #db rowcount(); " row(s).</b>"
        completed$ = completed$ + "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        headers$ = #db columnnames$()
        for j = 1 to countItems(headers$, ",")
          completed$ = completed$ + "<td class='tdheader'>" + trim$(getword$(headers$, j, ",")) + "</td>"
        next j
        completed$ = completed$ + "</tr>"
        for j = 1 to #db rowcount()
          tdWithClass$ = "<td class='td";j mod 2;"'>"
          completed$ = completed$ + "<tr>"
          row$ = #db nextrow$(DELIM$)
          for k = 1 to countItems(headers$, ",")
            completed$ = completed$ + tdWithClass$ + escapeHTML$(getword$(row$, k, DELIM$)) + "</td>"
          next k
          completed$ = completed$ + "</tr>"
        next j
        completed$ = completed$ + "</table><br/><br/>"
      else
        query$ = "SELECT changes() AS changes"
        #db execute(query$)
        #row = #db #nextrow()
        completed$ = completed$ + "<b>";#row changes();" row(s) affected.</b>"
      end if
      gosub [disconnect]
    end if
  next i
  goto [start]

[sqlError]
  completed$ = "<b>There is a problem with the syntax of your query (Query was not executed)</b><br/>"
  goto [start]

[tableSql]
  tableQueryStr$ = #queryval contents$()
  delimiter$ = #delimiter contents$()
  for i = 1 to countSql(tableQueryStr$, delimiter$)
    ' iterate through the queries exploded by the delimiter
    query$ = trim$(removeCRLF$(getsql$(tableQueryStr$, i, delimiter$)))
    if query$ <> "" then
      if left$(lower$(query$), 6) = "select" then isSelect = 1 else isSelect = 0
      gosub [connect]
      on error goto [sqlError]
      #db execute(query$)
      if isSelect and #db hasanswer() then
        completed$ = completed$ + "<b>Showing "; #db rowcount(); " row(s).</b>"
        completed$ = completed$ + "<table border='0' cellpadding='2' cellspacing='1' class='viewTable'>"
        headers$ = #db columnnames$()
        for j = 1 to countItems(headers$, ",")
          completed$ = completed$ + "<td class='tdheader'>" + trim$(getword$(headers$, j, ",")) + "</td>"
        next j
        completed$ = completed$ + "</tr>"
        for j = 1 to #db rowcount()
          tdWithClass$ = "<td class='td";j mod 2;"'>"
          completed$ = completed$ + "<tr>"
          row$ = #db nextrow$(DELIM$)
          for k = 1 to countItems(headers$, ",")
            completed$ = completed$ + tdWithClass$ + escapeHTML$(getword$(row$, k, DELIM$)) + "</td>"
          next k
          completed$ = completed$ + "</tr>"
        next j
        completed$ = completed$ + "</table><br/><br/>"
      else
        query$ = "SELECT changes() AS changes"
        #db execute(query$)
        #row = #db #nextrow()
        completed$ = completed$ + "<b>";#row changes();" row(s) affected.</b>"
      end if
      gosub [disconnect]
    end if
  next i
  goto [start]

[updateRows]
  for i = 1 to countItems(rowids$, ",")
    rowid$ = getword$(rowids$, i, ",")
    query$ = "PRAGMA table_info(" + tablename$ + ")"
    gosub [connect]
    #db execute(query$)
    query$ = ""   
    for j = 1 to #db rowcount()
      row$ = #db nextrow$(DELIM$)
      name$ = trim$(getword$(row$, 2, DELIM$))
      type$ = lower$(getword$(row$, 3, DELIM$))
      if type$ = "" then type$ = "null"
      notnull = val(getword$(row$, 4, DELIM$))          

      ' Function
      id$ = "function_";i;"_";name$
      f$ = #id$ selection$()

      ' Null
      id$ = "null_";i;"_";name$
      null = #id$ value()

      ' Value
      id$ = "field_";i;"_";name$
      value$ = #id$ contents$()

      ' Build update statement
      query$ = query$ + "," + name$ + " = "
      if f$ <> "" then query$ = query$ + f$ + "("
      if null or (type$ <> "text" and value$ = "") then
        query$ = query$ + "NULL"
      else
        query$ = query$ + quote$(value$)
      end if
      if f$ <> "" then query$ = query$ + ")"
    next j
    query$ = "update " + tablename$ + " set " + mid$(query$, 2) + " where rowid = " + quote$(rowid$)
    on error goto [updateError]
    #db execute(query$)
    completed$ = completed$ + "<span style='font-size:11px;'>" + query$ + "</span><br/>"
    gosub [disconnect]
  next i
  if nextAction$ = "" then
    action$ = "row_view"
  else
    action$ = nextAction$
    nextAction$ = ""
  end if
  goto [start]

[updateError]
  gosub [disconnect]
  completed$ = completed$ + "<b>There is a problem with the following update statement:</b><br/>"
  completed$ = completed$ + "<span style='font-size:11px;'>" + query$ + "</span><br/>"
  action$ = "row_view"
  goto [start]

[vacuum]
  query$ = "VACUUM"
  gosub [connect]
  #db execute(query$)
  gosub [disconnect]
  completed$ = "The database, '" + databaseNames$(currentDB) + "', has been VACUUMed."
  goto [start]

[import]
  ' user is importing a file
  ' $data = file_get_contents($_FILES["file"]["tmp_name"]);
  ' $db = new Database($databases[$_SESSION[COOKIENAME.'currentDB']]);
  ' $importSuccess = $db->import($data);

sub setupCSS
  ' overall styles for entire page
  cssclass "body", "{ margin:0px; padding:0px; font-family:Arial,Helvetica,sans-serif; font-size:14px; color:#000000; background-color:#e0ebf6; }"
  ' general styles for hyperlink
  cssclass "a", "{ color: #03F; text-decoration: none; cursor :pointer; }"
  cssclass "hr", "{ height: 1px; border: 0; color: #bbb; background-color: #bbb; width: 100%; }"
  cssclass "a:hover", "{ color: #06F; }"
  ' logo text containing name of project
  cssclass "h1", "{ margin: 0px; padding: 5px; font-size: 24px; background-color: #f3cece; text-align: center; margin-bottom: 10px; color: #000; border-top-left-radius:5px; border-top-right-radius:5px; -moz-border-radius-topleft:5px; -moz-border-radius-topright:5px; }"
  ' version text within the logo
  cssclass "h1 #version", "{ color: #000000; font-size: 16px; }"
  ' logo text within logo 
  cssclass "h1 #logo", "{ color:#000; }"
  ' general header for various views
  cssclass "h2", "{ margin:0px; padding:0px; font-size:14px; margin-bottom:20px; }"
  ' input buttons and areas for entering text
  cssclass "input, select, textarea", "{ font-family:Arial, Helvetica, sans-serif; background-color:#eaeaea; color:#03F; border-color:#03F; border-style:solid; border-width:1px; margin:5px; border-radius:5px; -moz-border-radius:5px; padding:3px; }"
  ' just input buttons
  cssclass "input.btn", "{ cursor:pointer; }"
  cssclass "input.btn:hover", "{ background-color:#ccc; }"
  ' general styles for hyperlink
  cssclass "fieldset", "{ padding:15px; border-color:#03F; border-width:1px; border-style:solid; border-radius:5px; -moz-border-radius:5px; background-color:#f9f9f9; }"
  ' outer div that holds everything
  cssclass "#container", "{ padding:10px; font-family:Arial,Helvetica,sans-serif; font-size:14px; white-space:normal; }"
  ' div of left box with log, list of databases, etc.
  cssclass "#leftNav", "{ float:left; min-width:250px; padding:0px; border-color:#03F; border-width:1px; border-style:solid; background-color:#FFF; padding-bottom:15px; border-radius:5px; -moz-border-radius:5px; }"
  ' div holding the content to the right of the leftNav
  cssclass "#content", "{ overflow:hidden; padding-left:10px; }"
  ' div holding the login fields
cssclass "#loginBox", "{ width:500px; margin-left:auto; margin-right:auto; margin-top:50px; border-color:#03F; border-width:1px; border-style:solid; background-color:#FFF; border-radius:5px; -moz-border-radius:5px; }"
  ' div under tabs with tab-specific content
  cssclass "#main", "{ border-color:#03F; border-width:1px; border-style:solid; padding:15px; overflow:auto; background-color:#FFF; border-bottom-left-radius:5px; border-bottom-right-radius:5px; border-top-right-radius:5px; -moz-border-radius-bottomleft:5px; -moz-border-radius-bottomright:5px; -moz-border-radius-topright:5px; }"
  ' odd-numbered table rows
  cssclass ".td1", "{ background-color:#f9e3e3; text-align:right; font-size:12px; padding-left:10px; padding-right:10px; }"
  ' even-numbered table rows
  cssclass ".td0", "{ background-color:#f3cece; text-align:right; font-size:12px; padding-left:10px; padding-right:10px; }"
  ' table column headers
  cssclass ".tdheader", "{ border-color:#03F; border-width:1px; border-style:solid; font-weight:bold; font-size:12px; padding-left:10px; padding-right:10px; background-color:#e0ebf6; border-radius:5px; -moz-border-radius:5px; }"
  ' div holding the confirmation text of certain actions
  cssclass ".confirm", "{ border-color:#03F; border-width:1px; border-style:dashed; padding:15px; background-color:#e0ebf6; }"
  ' tab navigation for each table
  cssclass ".tab", "{ display:block; padding:5px; padding-right:8px; padding-left:8px; border-color:#03F; border-width:1px; border-style:solid; margin-right:5px; float:left; border-bottom-style:none; position:relative; top:1px; padding-bottom:4px; background-color:#eaeaea; border-top-left-radius:5px; border-top-right-radius:5px; -moz-border-radius-topleft:5px; -moz-border-radius-topright:5px; }"
  cssclass ".tab_red", "{ display:block; padding:5px; padding-right:8px; padding-left:8px; border-color:#03F; border-width:1px; border-style:solid; margin-right:5px; float:left; border-bottom-style:none; position:relative; top:1px; padding-bottom:4px; background-color:#eaeaea; border-top-left-radius:5px; border-top-right-radius:5px; -moz-border-radius-topleft:5px; -moz-border-radius-topright:5px; color:red; }"
  ' pressed state of tab
  cssclass ".tab_pressed", "{ display:block; padding:5px; padding-right:8px; padding-left:8px; border-color:#03F; border-width:1px; border-style:solid; margin-right:5px; float:left; border-bottom-style:none; position:relative; top:1px; background-color:#FFF; cursor:default; border-top-left-radius:5px; border-top-right-radius:5px; -moz-border-radius-topleft:5px; -moz-border-radius-topright:5px; }"
  cssclass ".tab_pressed_red", "{ display:block; padding:5px; padding-right:8px; padding-left:8px; border-color:#03F; border-width:1px; border-style:solid; margin-right:5px; float:left; border-bottom-style:none; position:relative; top:1px; background-color:#FFF; cursor:default; border-top-left-radius:5px; border-top-right-radius:5px; -moz-border-radius-topleft:5px; -moz-border-radius-topright:5px; color:red; }"
  ' tooltip styles
  cssclass "#tt", "{ position:absolute; display:block; }"
  cssclass "#tttop", "{ display:block; height:5px; margin-left:5px; overflow:hidden }"
  cssclass "#ttcont", "{ display:block; padding:2px 12px 3px 7px; margin-left:5px; background:#f3cece; color:#333 }"
  cssclass "#ttbot", "{ display:block; height:5px; margin-left:5px; overflow:hidden }"
  cssclass ".red", "{ color: red; }"
end sub

function countItems(s$, d$)
  if s$ = "" then
    countItems = 0
  else
    countItems = 1
    for i = 1 to len(s$)
      if mid$(s$, i, 1) = d$ then countItems = countItems + 1
    next i
  end if
end function

function countSql(s$, d$)
  if s$ = "" then
    countSql = 0
  else
    countSql = 1
    for i = 1 to len(s$)
      c$ = mid$(s$, i, 1)
      select case c$
        case "'"
          if mid$(s$, i + 1, 1) = "'" then
            i = i + 1
          else
            inquotes = not(inquotes)
          end if
        case d$
          if not(inquotes) then countSql = countSql + 1
      end select
    next i
  end if
end function

function dequote$(s$)
  if left$(s$, 1) = "'" and right$(s$, 1) = "'" then
    for i = 2 to len(s$) - 1
      c$ = mid$(s$, i, 1)
      if c$ = "'" and mid$(s$, i + 1, 1) = "'" then i = i + 1
      dequote$ = dequote$ + c$
    next i
  else
    dequote$ = s$
  end if
end function

function escapeHTML$(s$)
  for i = 1 to len(s$)
    c$ = mid$(s$, i, 1)
    select case c$
      case "<" 
        escapeHTML$ = escapeHTML$ + "&lt;"
      case ">"
        escapeHTML$ = escapeHTML$ + "&gt;"
      case "&"
        escapeHTML$ = escapeHTML$ + "&amp;"
      case else
        escapeHTML$ = escapeHTML$ + c$
    end select
  next i
end function

function getword$(s$, n, d$)
  getword$ = word$(s$, n, d$)
  if getword$ = d$ then getword$ = ""
end function

function getsql$(s$, n, d$)
  count = 1
  start = 1
  for i = 1 to len(s$)
    c$ = mid$(s$, i, 1)
    select case c$ 
      case "'"
        if mid$(s$, i + 1, 1) = "'" then
          i = i + 1
        else
          inquotes = not(inquotes)
        end if
      case d$
        if not(inquotes) then
          if count = n then
            i = i - 1 ' skip the delimiter
            exit for
          else
            count = count + 1
            start = i + 1 ' skip the delimiter
          end if
        end if
    end select
  next i
  if count = n then getsql$ = mid$(s$, start, i - start + 1)
end function

function quote$(s$)
  if instr(s$, "'") = 0 then
    quote$ = s$
  else
    for i = 1 to len(s$)
      c$ = mid$(s$, i, 1)
      if c$ = "'" then quote$ = quote$ + "'"
      quote$ = quote$ + c$
    next i
  end if
  quote$ = "'" + quote$ + "'"
end function

function removeCRLF$(s$)
  for i = 1 to len(s$)
    c$ = mid$(s$, i, 2)
    if c$ = chr$(13) + chr$(10) then
      c$ = " "
      i = i + 1
    end if
    c$ = left$(c$, 1)
    if c$ = chr$(13) or c$ = chr$(10) then c$ = " "
    removeCRLF$ = removeCRLF$ + c$
  next i
end function
