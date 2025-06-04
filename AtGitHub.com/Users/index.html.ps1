<#
.SYNOPSIS
    AtGitHub Users Page
.DESCRIPTION
    Generates a list of GitHub users mentioned on BlueSky.
.LINK
    https://AtGitHub.com/Users
#>
if ($PSScriptRoot) { Push-Location $PSScriptRoot }
if ($psScriptRoot -and -not $site.AtGitHub) {
    . ($PSScriptRoot | Split-Path | Join-Path -ChildPath 'AtGitHub.DataSet.ps1')
}

$Title = "Users"
$Description = "GitHub Users"


"<style>"
"table {
    width: 90%;
    margin-left: auto;
    margin-right: auto;    
}"    
@'
.sr-only {
  position: absolute;
  top: -30em;
}

table.sortable td,
table.sortable th {
  padding: 0.125em 0.25em;  
}

table.sortable th {
  font-weight: bold;
  // border-bottom: thin solid var(--foreground);
  position: relative;
}

table.sortable th.no-sort {
  padding-top: 0.35em;
}

table.sortable th:nth-child(5) {
  width: 10em;
}

table.sortable th button {
  padding: 4px;
  margin: 1px;
  font-size: 100%;
  font-weight: bold;
  background: transparent;
  border: none;
  display: inline;
  right: 0;
  left: 0;
  top: 0;
  bottom: 0;
  width: 100%;
  text-align: left;
  outline: none;
  cursor: pointer;
}

table.sortable th button span {
  position: absolute;
  right: 4px;
}

table.sortable th[aria-sort="descending"] span::after {
  content: "▼";
  color: currentcolor;
  font-size: 100%;
  top: 0;
}

table.sortable th[aria-sort="ascending"] span::after {
  content: "▲";
  color: currentcolor;
  font-size: 100%;
  top: 0;
}

table.show-unsorted-icon th:not([aria-sort]) button span::after {
  content: "♢";
  color: currentcolor;
  font-size: 100%;
  position: relative;
  top: -3px;
  left: -4px;
}

table.sortable td.num {
  text-align: right;
}


/* Focus and hover styling */

table.sortable th button:focus,
table.sortable th button:hover {
  padding: 2px;
  border: 2px solid currentcolor;
  background-color: var(--background);
}

table.sortable th button:focus span,
table.sortable th button:hover span {
  right: 2px;
}

table.sortable th:not([aria-sort]) button:focus span::after,
table.sortable th:not([aria-sort]) button:hover span::after {
  content: "▼";
  color: currentcolor;
  font-size: 100%;
  top: 0;
}
'@

"</style>"

$reposTable = $site.AtData.Tables['github.repository']
$postsTable = $site.AtData.Tables['app.bsky.feed.post']
$likesTable = $site.AtData.Tables['app.bsky.feed.like']
$repostsTable = $site.AtData.Tables['app.bsky.feed.repost']

$totalInterations = $postsTable.Rows.Count + $likesTable.Rows.Count + $repostsTable.Rows.Count

#region Relative Weighting
$relativeWeights = @{
    'app.bsky.feed.post'    = 10 # * $postsTable.Rows.Count   / ($totalInterations - $postsTable.Rows.Count)
    'app.bsky.feed.like'    = 1 # * $likesTable.Rows.Count    / ($totalInterations - $likesTable.Rows.Count)
    'app.bsky.feed.repost'  = 5 # * $repostsTable.Rows.Count  / ($totalInterations - $repostsTable.Rows.Count)
}
#endregion Relative Weighting

$ownerSummary = [Ordered]@{}

$repoSummary = foreach ($row in $reposTable) {
    $mentions   = $row.GetChildRows('Mentions')
    $posts      = $mentions.GetChildRows('Posts')
    $likeCount      = 0
    $repostCount    = 0    
    foreach ($post in $posts) {
        $likeCount += $post.LikeCount
        $repostCount += $post.RepostCount
    }
    $score =
        ($posts.Count * $relativeWeights['app.bsky.feed.post']) +
        ($likeCount * $relativeWeights['app.bsky.feed.like']) + 
        ($repostCount * $relativeWeights['app.bsky.feed.repost'])

    $score = $score

    $score = [Math]::Round($score, 2)

    if (-not $ownerSummary[$row.Owner]) {
        $ownerSummary[$row.Owner] = [PSCustomObject][Ordered]@{
            PSTypeName = 'AtGitHub.Owner.Summary'
            Owner = $row.Owner
            Repositories = @()
            Mentions = @()
            Posts = @()
            Url = @()
            PostCount = 0
            LikeCount = 0
            RepostCount = 0
            Score = 0            
        }        
    }

    $ownerSummary[$row.Owner].Repositories += $row
    $ownerSummary[$row.Owner].Mentions += $mentions
    $ownerSummary[$row.Owner].Posts += $posts
    $ownerSummary[$row.Owner].Url += $mentions.Url
    $ownerSummary[$row.Owner].PostCount += $posts.Count
    $ownerSummary[$row.Owner].LikeCount += $likeCount
    $ownerSummary[$row.Owner].RepostCount += $repostCount
    $ownerSummary[$row.Owner].Score += $score

        
}

$userSummary = $ownerSummary.GetEnumerator() | Sort-Object {$_.Value.Score} -Descending | Select-Object -ExpandProperty Value


"<table class='sortable'>"
"<thead>"
"<tr>"
"<th class='num'><button>Rank<span aria-hidden='true'></span></button></th>"
"<th><button>Owner<span aria-hidden='true'></span></button></th>"
"<th><button>Repository<span aria-hidden='true'></span></button></th>"
"<th class='num'><button>Posts<span aria-hidden='true'></span></button></th>"
"<th class='num'><button>Likes<span aria-hidden='true'></span></button></th>"
"<th class='num'><button>Reposts<span aria-hidden='true'></span></button></th>"
"<th aria-sort='descending' class='num'><button>Score<span aria-hidden='true'></span></button></th>"
"</tr>"
"</thead>"
"<tbody>"
$rank = 0
foreach ($user in $userSummary) {    
"<tr>"
$rank++
"<td id='rank-$rank'>"
$rank
"</td>"
"<td id='$($user.Owner)'>"
"<a href='https://github.com/$($user.owner)'>"
$user.Owner
"</a>"
"</td>"
"<td>"
@(foreach ($repo in $user.Repositories) {    
    @(
        "<a href='https://github.com/$($repo.owner)/$($repo.Repository)'>"
            if ($repo.Repository.Length -gt 40) {
                $repo.Repository.Substring(0, 40) + '...'
            } else {
                $repo.Repository
            }
        "</a>"
    ) -join ''
}) -join '<br />'
"</td>"
"<td>"
$user.PostCount
"</td>"
"<td>"
$user.LikeCount
"</td>"
"<td>"
$user.RepostCount
"</td>"
"<td>"
$user.Score
"</td>"
"</tr>"    
}
"</tbody>"
"</table>"
"<script>"
@'
'use strict';

class SortableTable {
  constructor(tableNode) {
    this.tableNode = tableNode;

    this.columnHeaders = tableNode.querySelectorAll('thead th');

    this.sortColumns = [];

    for (var i = 0; i < this.columnHeaders.length; i++) {
      var ch = this.columnHeaders[i];
      var buttonNode = ch.querySelector('button');
      if (buttonNode) {
        this.sortColumns.push(i);
        buttonNode.setAttribute('data-column-index', i);
        buttonNode.addEventListener('click', this.handleClick.bind(this));
      }
    }

    this.optionCheckbox = document.querySelector(
      'input[type="checkbox"][value="show-unsorted-icon"]'
    );

    if (this.optionCheckbox) {
      this.optionCheckbox.addEventListener(
        'change',
        this.handleOptionChange.bind(this)
      );
      if (this.optionCheckbox.checked) {
        this.tableNode.classList.add('show-unsorted-icon');
      }
    }
  }

  setColumnHeaderSort(columnIndex) {
    if (typeof columnIndex === 'string') {
      columnIndex = parseInt(columnIndex);
    }

    for (var i = 0; i < this.columnHeaders.length; i++) {
      var ch = this.columnHeaders[i];
      var buttonNode = ch.querySelector('button');
      if (i === columnIndex) {
        var value = ch.getAttribute('aria-sort');
        if (value === 'descending') {
          ch.setAttribute('aria-sort', 'ascending');
          this.sortColumn(
            columnIndex,
            'ascending',
            ch.classList.contains('num')
          );
        } else {
          ch.setAttribute('aria-sort', 'descending');
          this.sortColumn(
            columnIndex,
            'descending',
            ch.classList.contains('num')
          );
        }
      } else {
        if (ch.hasAttribute('aria-sort') && buttonNode) {
          ch.removeAttribute('aria-sort');
        }
      }
    }
  }

  sortColumn(columnIndex, sortValue, isNumber) {
    function compareValues(a, b) {
      if (sortValue === 'ascending') {
        if (a.value === b.value) {
          return 0;
        } else {
          if (isNumber) {
            return a.value - b.value;
          } else {
            return a.value < b.value ? -1 : 1;
          }
        }
      } else {
        if (a.value === b.value) {
          return 0;
        } else {
          if (isNumber) {
            return b.value - a.value;
          } else {
            return a.value > b.value ? -1 : 1;
          }
        }
      }
    }

    if (typeof isNumber !== 'boolean') {
      isNumber = false;
    }

    var tbodyNode = this.tableNode.querySelector('tbody');
    var rowNodes = [];
    var dataCells = [];

    var rowNode = tbodyNode.firstElementChild;

    var index = 0;
    while (rowNode) {
      rowNodes.push(rowNode);
      var rowCells = rowNode.querySelectorAll('th, td');
      var dataCell = rowCells[columnIndex];

      var data = {};
      data.index = index;
      data.value = dataCell.textContent.toLowerCase().trim();
      if (isNumber) {
        data.value = parseFloat(data.value);
      }
      dataCells.push(data);
      rowNode = rowNode.nextElementSibling;
      index += 1;
    }

    dataCells.sort(compareValues);

    // remove rows
    while (tbodyNode.firstChild) {
      tbodyNode.removeChild(tbodyNode.lastChild);
    }

    // add sorted rows
    for (var i = 0; i < dataCells.length; i += 1) {
      tbodyNode.appendChild(rowNodes[dataCells[i].index]);
    }
  }

  /* EVENT HANDLERS */

  handleClick(event) {
    var tgt = event.currentTarget;
    this.setColumnHeaderSort(tgt.getAttribute('data-column-index'));
  }

  handleOptionChange(event) {
    var tgt = event.currentTarget;

    if (tgt.checked) {
      this.tableNode.classList.add('show-unsorted-icon');
    } else {
      this.tableNode.classList.remove('show-unsorted-icon');
    }
  }
}

// Initialize sortable table buttons
window.addEventListener('load', function () {
  var sortableTables = document.querySelectorAll('table.sortable');
  for (var i = 0; i < sortableTables.length; i++) {
    new SortableTable(sortableTables[i]);
  }
});
'@
"</script>"


if ($PSScriptRoot) { Pop-Location }
