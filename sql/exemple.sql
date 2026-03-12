--12

--Care sunt instructorii care predau balet în sali unde mai sunt locuri disponibile?
SELECT
    i.nume AS instructor,
    s.nume AS sala,
    s.capacitate,
    COUNT(p.elev_id) AS nr_participanti,
    CASE
        WHEN COUNT(p.elev_id) < s.capacitate THEN 'Locuri disponibile'
        ELSE 'Sala plina'
    END AS status
FROM curs c
JOIN instructor i ON c.instructor_id = i.instructor_id
JOIN sala s ON c.sala_id = s.sala_id
JOIN stil st ON c.stil_id = st.stil_id
LEFT JOIN participa p ON p.curs_id = c.curs_id
WHERE UPPER(st.nume) = 'BALET'
GROUP BY i.nume, s.nume, s.capacitate
HAVING COUNT(p.elev_id) < s.capacitate
ORDER BY i.nume;

--Cati bani s-au incasat in total din abonamente si cati din cursuri?
WITH sume AS (
    SELECT 'abonament' AS tip, SUM(b.suma) AS total
    FROM bani b JOIN bani_abonament ba ON ba.bani_id = b.bani_id
    UNION ALL
    SELECT 'curs', SUM(b.suma)
    FROM bani b JOIN bani_curs bc ON bc.bani_id = b.bani_id
)
SELECT UPPER(tip) AS sursa_venit, total
FROM sume
ORDER BY total DESC;

--Ce instructori nu au primit salariu luna aceasta?
SELECT
    i.nume AS instructor,
    NVL(TO_CHAR(MAX(b.data_plata), 'YYYY-MM-DD'), 'Fara plata') AS ultima_plata,
    DECODE(
        SIGN(NVL(MAX(b.data_plata) - ADD_MONTHS(SYSDATE, -1), -1)),
        1, 'Platit',
        0, 'Platit',
        -1, 'Neplatit'
    ) AS status
FROM instructor i
LEFT JOIN salariu s ON s.instructor_id = i.instructor_id
LEFT JOIN bani b ON b.bani_id = s.bani_id
GROUP BY i.nume
ORDER BY MAX(b.data_plata) NULLS FIRST;

--Care sunt elevii care au abonamente active cu un numar de sedinte sub media tuturor abonamentelor active?
SELECT
    UPPER(e.nume) AS nume_elev,
    e.email,
    a.nr_sedinte,
    CASE
        WHEN INSTR(NVL(e.email, ' '), '@') = 0 THEN 'Email invalid'
        ELSE 'Email valid'
    END AS status_email
FROM abonament a
JOIN elev e ON a.elev_id = e.elev_id
WHERE a.activ = 'DA'
GROUP BY e.nume, e.email, a.nr_sedinte
HAVING a.nr_sedinte < (
    SELECT AVG(nr_sedinte)
    FROM abonament
    WHERE activ = 'DA'
)
ORDER BY a.nr_sedinte;

--Care sunt cursurile cu mai mult de 2 cerinte, care au cel putin un elev cu abonament activ?
SELECT
    c.curs_id,
    i.nume AS instructor,
    sub.nr_cerinte
FROM curs c
JOIN instructor i ON c.instructor_id = i.instructor_id
JOIN (
    SELECT
        cc.curs_id,
        COUNT(cc.cerinta_id) AS nr_cerinte
    FROM cerinta_curs cc
    JOIN cerinta ce ON ce.cerinta_id = cc.cerinta_id
    JOIN curs cu ON cu.curs_id = cc.curs_id
    GROUP BY cc.curs_id
) sub ON sub.curs_id = c.curs_id
WHERE sub.nr_cerinte > 2
GROUP BY i.nume, c.curs_id, sub.nr_cerinte
HAVING EXISTS (
    SELECT 1
    FROM participa p
    JOIN abonament a ON a.elev_id = p.elev_id
    JOIN elev e ON e.elev_id = p.elev_id
    WHERE p.curs_id = c.curs_id
      AND a.activ = 'DA'
)
ORDER BY i.nume, c.curs_id;


--13

--Schimba nivelul stilului de dans cu cele mai multe cursuri
UPDATE STIL
SET NIVEL = 'Avansat'
WHERE STIL_ID = (
    SELECT STIL_ID
    FROM (
        SELECT STIL_ID, COUNT(*) AS NR_CURSURI
        FROM CURS
        GROUP BY STIL_ID
        ORDER BY NR_CURSURI DESC
    )
    WHERE ROWNUM = 1
);

--Modifica pretul abonamentului la 100 pt cele care au mai mult de 10 sedinte
UPDATE ABONAMENT
SET PRET = 100
WHERE NR_SEDINTE > 10
AND ABONAMENT_ID IN (
    SELECT ABONAMENT_ID FROM ABONAMENT
);

--Sterge feedback cu nota mai mica de 5
DELETE FROM FEEDBACK
WHERE NOTA < 5
AND ELEV_ID IN (
    SELECT ELEV_ID FROM FEEDBACK
);


--14

--Vizualizare complexa care uneste elevii cu abonament cu cursul la care participa si detalii despre abonamentul lor
CREATE OR REPLACE VIEW VIEW_ELEV_CURS_ABONAMENTE AS
SELECT
    e.elev_id,
    e.nume AS nume_elev,
    c.curs_id,
    s.nume AS stil_dans,
    a.abonament_id,
    a.activ,
    a.nr_sedinte,
    a.perioada_start,
    a.perioada_end
FROM
    ELEV e
JOIN
    ABONAMENT a ON e.elev_id = a.elev_id
JOIN
    PARTICIPA p ON e.elev_id = p.elev_id
JOIN
    CURS c ON p.curs_id = c.curs_id
JOIN
    STIL s ON c.stil_id = s.stil_id;

--Operatie LMD permisa
SELECT *
FROM VIEW_ELEV_CURS_ABONAMENTE
WHERE activ = 'DA' AND nr_sedinte < 10;

--Operatie LMD nepermisa
UPDATE VIEW_ELEV_CURS_ABONAMENTE
SET nr_sedinte = nr_sedinte + 1
WHERE abonament_id = 1;


--15

--Cerere cu outer-join pe 4 tabele
SELECT
    i.nume AS instructor_nume,
    c.curs_id,
    s.nume AS nume_sala,
    st.nume AS stil_dans
FROM
    INSTRUCTOR i
LEFT JOIN CURS c ON i.instructor_id = c.instructor_id
LEFT JOIN SALA s ON c.sala_id = s.sala_id
LEFT JOIN STIL st ON c.stil_id = st.stil_id
ORDER BY i.nume;

--Cerere care utilizeaza operatia de divizare
SELECT e.nume
FROM ELEV e
WHERE NOT EXISTS (
    SELECT c.curs_id
    FROM CURS c
    JOIN STIL s ON c.stil_id = s.stil_id
    WHERE s.nume = 'Hip-Hop'
    MINUS
    SELECT p.curs_id
    FROM PARTICIPA p
    WHERE p.elev_id = e.elev_id
);

--Cerere care implementeaza analiza TOP-N
SELECT *
FROM (
    SELECT i.instructor_id, i.nume, COUNT(f.nota) AS nr_feedbackuri
    FROM FEEDBACK f
    JOIN CURS c ON f.curs_id = c.curs_id
    JOIN INSTRUCTOR i ON c.instructor_id = i.instructor_id
    GROUP BY i.instructor_id, i.nume
    ORDER BY COUNT(f.nota) DESC
)
WHERE ROWNUM <= 2;


--16

--Aleg interogarea a 5-a de la cerinta 12:
--Care sunt cursurile cu mai mult de 2 cerinte, care au cel putin un elev cu abonament activ?

--Planul de executie al interogarii neoptimizate
EXPLAIN PLAN FOR
SELECT
    c.curs_id,
    i.nume AS instructor,
    sub.nr_cerinte
FROM curs c
JOIN instructor i ON c.instructor_id = i.instructor_id
JOIN (
    SELECT
        cc.curs_id,
        COUNT(cc.cerinta_id) AS nr_cerinte
    FROM cerinta_curs cc
    JOIN cerinta ce ON ce.cerinta_id = cc.cerinta_id
    JOIN curs cu ON cu.curs_id = cc.curs_id
    GROUP BY cc.curs_id
) sub ON sub.curs_id = c.curs_id
WHERE sub.nr_cerinte > 2
GROUP BY i.nume, c.curs_id, sub.nr_cerinte
HAVING EXISTS (
    SELECT 1
    FROM participa p
    JOIN abonament a ON a.elev_id = p.elev_id
    JOIN elev e ON e.elev_id = p.elev_id
    WHERE p.curs_id = c.curs_id
      AND a.activ = 'DA'
)
ORDER BY i.nume, c.curs_id;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

--Creez un index pt ABONAMENT, PARTICIPA si CERINTA_CURS
CREATE INDEX idx_abonament_activ ON ABONAMENT(elev_id, activ);
CREATE INDEX idx_participa_curs ON PARTICIPA(curs_id, elev_id);
CREATE INDEX idx_curs_cerinta ON CERINTA_CURS(curs_id);

--Varianta optimizata a interogarii
SELECT /*+ USE_NL(c cc) USE_NL(p) USE_NL(a) */
       c.curs_id
FROM curs c
JOIN cerinta_curs cc ON c.curs_id = cc.curs_id
JOIN instructor i ON c.instructor_id = i.instructor_id
GROUP BY c.curs_id
HAVING COUNT(cc.cerinta_id) > 2
AND EXISTS (
  SELECT /*+ INDEX(a idx_abonament_activ) INDEX(p idx_participa_curs) */
         0
  FROM participa p, abonament a
  WHERE p.curs_id = c.curs_id
    AND a.elev_id = p.elev_id
    AND a.activ = 'DA'
);

--Planul dupa optimizare
EXPLAIN PLAN FOR
SELECT /*+ USE_NL(c cc) USE_NL(p) USE_NL(a) */
       c.curs_id
FROM curs c
JOIN cerinta_curs cc ON c.curs_id = cc.curs_id
JOIN instructor i ON c.instructor_id = i.instructor_id
GROUP BY c.curs_id
HAVING COUNT(cc.cerinta_id) > 2
AND EXISTS (
  SELECT /*+ INDEX(a idx_abonament_activ) INDEX(p idx_participa_curs) */
         0
  FROM participa p, abonament a
  WHERE p.curs_id = c.curs_id
    AND a.elev_id = p.elev_id
    AND a.activ = 'DA'
);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

