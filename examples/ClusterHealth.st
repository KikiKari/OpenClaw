"OpenClaw Cluster Health Summary (Smalltalk)"
| statuses ok availability |
statuses := #(200 200 503 200).
ok := (statuses select: [:s | s = 200]) size.
statuses keysAndValuesDo: [:i :s |
    Transcript showCr: 'node ', i printString, ' -> HTTP ', s printString].
availability := (100 * ok) // statuses size.
Transcript showCr: 'cluster availability: ', availability printString, ' %'.
