# Reduce Shaep output to two columns.
# Assumes that input has no header-line
BEGIN {
  OFS="\t"
  print "name\tvalues"    # Insert headers for the table
}
{
  # First column has molecule's name
  # Remove _entry... from name
  sub(/_entry.*/, "", $1)
  # Some names have _0... (DUD-E, LIGPREP, PLANTS?)
  sub(/_0.*/, "", $1)
  # Remove colons (and suffix)
  sub(/:.*/, "", $1)
  # Now all instances of a ligand have identical name
  if (!a[$1] || $2>a[$1]) a[$1]=$2 # Pick only the largest value from every ligand
}
END {
  for (f in a) print f,a[f]
}
