cat > run_all.sh << 'EOF'
#!/bin/bash
# ============================================
# run_all.sh <время_в_нс>
# Полный цикл MD для ADH + NADH
# Пример: ./run_all.sh 50
# ============================================
set -e

# === ПРОВЕРКА АРГУМЕНТОВ ===
if [ $# -ne 1 ]; then
    echo "Использование: $0 <время_в_нс>"
    echo "Пример: $0 50"
    exit 1
fi

MD_TIME_NS=$1

if ! [[ "$MD_TIME_NS" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: время должно быть целым числом (в наносекундах)"
    exit 1
fi

# Расчёт количества шагов
TIME_STEP=0.002  # пс
STEPS_PER_NS=500000  # 1 нс = 500 000 шагов по 0.002 пс
MD_STEPS=$((MD_TIME_NS * STEPS_PER_NS))

echo "=========================================="
echo "  ЗАПУСК MD ДЛЯ ADH + NADH"
echo "  Длительность: ${MD_TIME_NS} нс (${MD_STEPS} шагов)"
echo "=========================================="

# === КОНФИГУРАЦИЯ ===
PDB_FILE="1mg5.pdb"
FF="charmm36-feb2026_cgenff-5.0"
WATER="tip3p"
BOX_DIST="1.0"
BOX_TYPE="cubic"
NVT_STEPS=50000
NPT_STEPS=50000
TEMP=300
NPROC=8
GPU_ID=0

# === ЭТАП 1: ПАРАМЕТРИЗАЦИЯ ===
echo ""
echo "=== ЭТАП 1: ПАРАМЕТРИЗАЦИЯ ==="

echo "[1.1] Параметризация комплекса..."
gmx pdb2gmx -f "$PDB_FILE" -o complex.gro -water "$WATER" \
    -ff "$FF" -ignh -merge all -chainsep id_and_ter

echo "[1.2] Создание ящика..."
gmx editconf -f complex.gro -o box.gro -c -d "$BOX_DIST" -bt "$BOX_TYPE"

echo "[1.3] Сольватация..."
gmx solvate -cp box.gro -cs spc216.gro -o solv.gro -p topol.top

echo "[1.4] Создание ions.mdp..."
cat > ions.mdp << EOFMDP
integrator      = steep
nsteps          = 0
emtol           = 1000.0
emstep          = 0.01
nstlist         = 1
cutoff-scheme   = Verlet
coulombtype     = PME
rcoulomb        = 1.2
rvdw            = 1.2
pbc             = xyz
EOFMDP

echo "[1.5] Добавление ионов..."
gmx grompp -f ions.mdp -c solv.gro -p topol.top -o ions.tpr -maxwarn 1
echo "SOL" | gmx genion -s ions.tpr -o solv_ions.gro -p topol.top \
    -pname NA -nname CL -neutral

# === ЭТАП 2: МИНИМИЗАЦИЯ ===
echo ""
echo "=== ЭТАП 2: МИНИМИЗАЦИЯ ЭНЕРГИИ ==="

cat > minim.mdp << EOFMDP
integrator      = steep
nsteps          = 50000
emtol           = 1000.0
emstep          = 0.01
nstlist         = 1
cutoff-scheme   = Verlet
coulombtype     = PME
rcoulomb        = 1.2
rvdw            = 1.2
pbc             = xyz
EOFMDP

gmx grompp -f minim.mdp -c solv_ions.gro -p topol.top -o em.tpr -maxwarn 1
gmx mdrun -v -deffnm em -ntmpi 1 -ntomp "$NPROC" -gpu_id "$GPU_ID"

echo "Проверка минимизации:"
grep "Potential" em.log | tail -3

# === ЭТАП 3: NVT-РЕЛАКСАЦИЯ ===
echo ""
echo "=== ЭТАП 3: NVT-РЕЛАКСАЦИЯ ==="

cat > nvt.mdp << EOFMDP
integrator      = md
nsteps          = $NVT_STEPS
dt              = $TIME_STEP
tcoupl          = V-rescale
tc-grps         = Protein non-Protein
tau-t           = 0.1 0.1
ref-t           = $TEMP $TEMP
pcoupl          = no
pbc             = xyz
cutoff-scheme   = Verlet
coulombtype     = PME
rcoulomb        = 1.2
rvdw            = 1.2
DispCorr        = EnerPres
nstlist         = 10
nstxout-compressed = 1000
constraints     = h-bonds
constraint-algorithm = LINCS
continuation    = no
gen-vel         = yes
gen-temp        = $TEMP
EOFMDP

gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -maxwarn 1
gmx mdrun -v -deffnm nvt -ntmpi 1 -ntomp "$NPROC" -gpu_id "$GPU_ID"

# === ЭТАП 4: NPT-РЕЛАКСАЦИЯ ===
echo ""
echo "=== ЭТАП 4: NPT-РЕЛАКСАЦИЯ ==="

cat > npt.mdp << EOFMDP
integrator      = md
nsteps          = $NPT_STEPS
dt              = $TIME_STEP
tcoupl          = V-rescale
tc-grps         = Protein non-Protein
tau-t           = 0.1 0.1
ref-t           = $TEMP $TEMP
pcoupl          = Berendsen
pcoupltype      = isotropic
tau-p           = 2.0
ref-p           = 1.0
compressibility = 4.5e-5
pbc             = xyz
cutoff-scheme   = Verlet
coulombtype     = PME
rcoulomb        = 1.2
rvdw            = 1.2
DispCorr        = EnerPres
nstlist         = 10
nstxout-compressed = 1000
constraints     = h-bonds
constraint-algorithm = LINCS
continuation    = yes
gen-vel         = no
EOFMDP

gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -maxwarn 1
gmx mdrun -v -deffnm npt -ntmpi 1 -ntomp "$NPROC" -gpu_id "$GPU_ID"

echo "Проверка плотности:"
echo "24" | gmx energy -f npt.edr -o density.xvg 2>&1 | grep "Density" | tail -1

# === ЭТАП 5: ПРОДУКТИВНЫЙ MD ===
echo ""
echo "=== ЭТАП 5: ПРОДУКТИВНЫЙ MD (${MD_TIME_NS} нс) ==="

cat > md.mdp << EOFMDP
integrator      = md
nsteps          = $MD_STEPS
dt              = $TIME_STEP
tcoupl          = V-rescale
tc-grps         = Protein non-Protein
tau-t           = 0.1 0.1
ref-t           = $TEMP $TEMP
pcoupl          = Parrinello-Rahman
pcoupltype      = isotropic
tau-p           = 2.0
ref-p           = 1.0
compressibility = 4.5e-5
pbc             = xyz
cutoff-scheme   = Verlet
coulombtype     = PME
rcoulomb        = 1.2
rvdw            = 1.2
DispCorr        = EnerPres
nstlist         = 10
nstxout-compressed = 5000
constraints     = h-bonds
constraint-algorithm = LINCS
continuation    = yes
gen-vel         = no
EOFMDP

gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr -maxwarn 1

echo ""
echo "=========================================="
echo "  ЗАПУСК ПРОДУКТИВНОГО MD"
echo "  Длительность: ${MD_TIME_NS} нс"
echo "  Шагов: ${MD_STEPS}"
echo "=========================================="

gmx mdrun -v -deffnm md -ntmpi 1 -ntomp "$NPROC" -gpu_id "$GPU_ID"

echo ""
echo "=========================================="
echo "  РАСЧЁТ ЗАВЕРШЁН!"
echo "  Траектория: md.xtc"
echo "  Энергия:    md.edr"
echo "  Координаты: md.gro"
echo "=========================================="
EOF

chmod +x run_all.sh
