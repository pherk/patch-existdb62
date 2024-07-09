xquery version "3.0";
declare namespace fhir= "http://hl7.org/fhir";

let $besuch :=
(
      6995289
    , 7109160
    , 6820710
    , 6694705
    , 7102691
    , 6235807
    , 7117188
    , 6346829
    , 7005371
    , 7071359
    , 5951914
    , 6333370
    , 6449551
    , 7123588
    , 6985181
    , 6249014
    , 7126278
    , 7032899
    , 6906444
    , 6776411
    , 7051459
    , 6801725
    , 6792818
    , 7128282
    , 6986031
    , 6652617
    , 6931888
    , 6909832
    , 6747573
    , 6653805
    , 6199503
    , 6690538
    , 7012670
    , 6796481
    , 6371064
    , 7084107
    , 6357056
    , 6270088
    , 6166128
    , 6300036
    , 6243257
    , 6644680
    , 6392182
    , 5925365
    , 6903588
    , 7071051
    , 6986769
    , 6870282
    , 6778091
    , 5553836
    , 6250270
    , 6884117
    , 6894672
    , 6823863
    , 6823864
    , 7130638
    , 6272555
    , 6898669
    , 6066371
    , 6266751
    , 7067096
    , 6521038
    , 6387196
    , 6814502
    , 6444574
    , 7034030
    , 6960468
    , 6951361
    , 7078693
    , 7114752
    , 6849548
    , 6858007
    , 7078889
    , 6747768
    , 7076244
    , 6839718
    , 6839071
    , 6907873
    , 6589548
    , 6672255
    , 6833354
    , 7132254
    , 6762669
    , 7049793
    , 6605343
    , 6664411
    , 6992155
    , 7132381
    , 6401834
    , 7029653
    , 6847768
    , 6889858
    , 7132399
    , 6526163
    , 6993002
    , 6933696
    , 6569530
    , 6283739
    , 7046290
    , 6972056
    , 6798558
    , 6966713
    , 6977695
    , 6651837
    , 6575361
    , 7048414
    , 6650778
    , 6583539
    , 6974605
    , 6649165
    , 6854848
    , 7133907
    , 7003409
    , 6618326
    , 7037027
    , 6946049
    , 6695145
    , 6737421
    , 6916309
    , 6797973
    , 7134888
    , 6920525
    , 7061601
    , 6515414
    , 7023777
    , 6944407
    , 6661845
    , 6667451
    , 6403936
    , 6910558
    , 6510461
    , 6566998
    , 6856736
    , 7105801
    , 6882455
    , 6762369
    , 6963920
    , 6861914
    , 7059598
    , 7083267
    , 6912025
    , 6565895
    , 6686124
    , 6532511
    , 6978439
    , 6522644
    , 6776411
    , 7060347
    , 6576775
    , 6820850
    , 7135890
    , 6477069
    , 6832550
    , 6357554
    , 6435458
    , 6089191
    , 6797603
    , 6689550
    , 6915159
    , 6489807
    , 6544638
    , 6767388
    , 6877007
    , 6415248
    , 6924115
    , 6773862
    , 6974879
    , 7004414
    , 7027805
    , 6674175
    , 7085226
    , 6893066
    , 6563561
    , 6328092
    , 7092291
    , 6643105
    , 6788819
    , 7125962
    , 6248850
    , 6729603
    , 7077733
    , 6601361
    , 6784414
    , 7113159
    , 7127898
    , 7125947
    , 6728679
    , 6704589
    , 6655493
    , 6740401
    , 6352016
    , 6554602
    , 6686939
    , 6899557
    , 7006973
    , 6648479
    , 7068617
    , 6281354
    , 6412875
    , 6945726
    , 6809095
    , 6793720
    , 7026912
    , 7118391
    , 6521449
    , 6419819
    , 7043367
    , 5959035
    , 6494281
    , 6729071
    , 6534117
    , 7122567
    , 6152986
    , 6768589
    , 6897961
    , 6904707
    , 6980866
    , 7110350
    , 6937033
    , 7031670
    , 6985824
    , 7115047
    , 5898525
    , 7044706
    , 7068496
    , 5811526
    , 6556552
    , 7073022
    , 7121865
    , 7121402
    , 6455520
    , 7123737
    , 6622122
    , 6952657
    , 6350221
    , 6727612
    , 6896218
    , 6995295
    , 7070933
    , 6910142
    , 7091599
    , 7091522
    , 6278715
    , 6380602
    , 6976264
    , 6682861
    , 7054380
    , 6531551
    , 6662187
    , 6270834
    , 6914474
    , 6964763
    , 5945191
    , 6110507
    , 6980728
    , 6419759
    , 6427466
    , 7076006
    , 6251836
    , 6290844
    , 6717786
    , 6904569
    , 6384189
    , 6542962
    , 6443741
    , 6643752
    , 6851331
    , 6177652
    , 6795692
    , 6654117
    , 7070641
    , 6940169
    , 7123937
    , 6614567
    , 7125331
    , 7126416
    , 7127575
    , 6524872
    , 6110507
    , 6874746
    , 7004650
    , 6940169
    , 6954519
    , 6741251
    , 6418138
    , 6889338
    , 5968378
    , 7083134
    , 7027077
    , 6790590
    , 6393346
    , 7064582
    , 7136169
    , 7084281
    , 7139010
    , 6781626
    , 7040556
    , 6415977
    , 6032184
    , 6507055
    , 6234573
    , 6326463
   )

let $year := '2023'
let $pc := collection('/db/apps/nabuData/data/FHIR/Patients')/fhir:Patient[fhir:active[@value="true"]]
let $ec := collection('/db/apps/nabuEncounter/data/' || $year)/fhir:Encounter
let $cc := collection('/db/apps/nabuCom/data/Conditions')/fhir:Condition
return
<patients>
    {
for $id in distinct-values($besuch)
let $p := $pc/../fhir:Patient[fhir:identifier[fhir:value/@value=$id]]

return

    if (count($p)=1)
    then
        let $pref := concat("nabu/patients/",$p/fhir:id/@value)
        let $eps := $ec/../fhir:Encounter[fhir:subject[fhir:reference/@value=$pref]][fhir:status[@value='finished']]
        let $cs := $cc/../fhir:Condition[fhir:subject[fhir:reference/@value=$pref]][fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]]
        let $ccs := $cs/../fhir:Condition[fhir:verificationStatus[@value='confirmed']]
        return
            <info id="{$id}" name="{$p/fhir:text/*:div/*:div}">
            { if (count($eps)>0)
              then
                for $e in $eps/../fhir:Encounter
                let $reason := if ($e/fhir:basedOn/fhir:display/@value=('spontan','Request Import','Human-friendly name for the CarePlan ...'))
                    then $e/fhir:reason/fhir:text/@value
                    else $e/fhir:basedOn/fhir:display/@value
                order by $e/fhir:period/fhir:start/@value
                return
                    <e date="{$e/fhir:period/fhir:start/@value}"
                       e="{$e/fhir:participant/fhir:actor/fhir:display/@value}"
                       s="{$e/fhir:participant/fhir:type/fhir:coding/fhir:display/@value}"
                       r="{$reason}"></e>
              else
                <e>Kein Besuch</e>
            }
            { if (count($ccs)>0)
              then
                  for $c in $ccs
                  return
                      <dx icd="{$c/fhir:code/fhir:coding[fhir:system[@value="http://hl7.org/fhir/sid/icd-10-de"]]/fhir:code/@value}">{$c/fhir:code/fhir:text/@value}</dx>
              else if (count($cs) > 0)
              then
                  let $scs :=  for $c in $cs
                        order by $c/fhir:assertDate/@value
                        return
                            $c
                  return
                      for $c in subsequence($scs,1,5)
                      return
                      <dxu icd="{$c/fhir:code/fhir:coding[fhir:system/@value="http://hl7.org/fhir/sid/icd-10-de"]/fhir:code/@value}">{$c/fhir:code/fhir:text/@value}</dxu>
              else
                <dx>Keine Diagnose</dx>
            }
            </info>
    else if (count($p)>1)
    then
        <dub>{$p}</dub>
    else
        <info id="{$id}">Keine ORBIS PID</info>
    }
</patients>