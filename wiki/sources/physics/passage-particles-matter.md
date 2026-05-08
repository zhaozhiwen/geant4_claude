---
type: source
domain: physics
status: stable
source: PDG 2025 Review of Particle Physics, Chapter 34 "Passage of Particles Through Matter"
source_url: https://pdg.lbl.gov/2025/reviews/rpp2025-rev-passage-particles-matter.pdf
license: CC-BY-4.0
citation: S. Navas et al. (Particle Data Group), Phys. Rev. D 110, 030001 (2024) and 2025 update.
related: ["[[pdg-api-access]]", "[[em-processes]]", "[[optical-photon-physics]]", "[[passage-particles-matter-summary]]"]
---

# Passage of Particles Through Matter (PDG Ch. 34) — full content

> Verbatim rendering of PDG Ch. 34, revised August 2023 by D.E. Groom (LBNL) and S.R. Klein (NSD LBNL; UC Berkeley). For a tighter wiki summary that paraphrases prose and adds a Geant4 cross-references appendix, see [[passage-particles-matter-summary]].
>
> *Source*: PDG 2025 Review of Particle Physics, Phys. Rev. D 110, 030001 (2024) and 2025 update. Released under CC-BY-4.0.

## 34.1 Notation

The notation and important numerical values are shown in Table 34.1.

**Table 34.1:** Summary of variables used in this section. The kinematic variables $\beta$ and $\gamma$ have their usual relativistic meanings.

| Symb. | Definition | Value or (usual) units |
|---|---|---|
| $m_e c^2$ | electron mass $\times\, c^2$ | 0.510 998 950 00(15) MeV |
| $r_e$ | classical electron radius $e^2/4\pi\epsilon_0 m_e c^2$ | 2.817 940 3227(19) fm |
| $\alpha$ | fine structure constant $e^2/4\pi\epsilon_0 \hbar c$ | 1/137.035 999 139(31) |
| $N_A$ | Avogadro's number | $6.022\,140\,76 \times 10^{23}$ mol$^{-1}$ |
| $\rho$ | density | g cm$^{-3}$ |
| $x$ | mass per unit area | g cm$^{-2}$ |
| $M$ | incident particle mass | MeV/$c^2$ |
| $E$ | incident part. energy $\gamma M c^2$ | MeV |
| $T$ | kinetic energy, $(\gamma - 1) M c^2$ | MeV |
| $W$ | energy transfer to an electron in a single collision | MeV |
| $W_{\max}$ | Maximum possible energy transfer to an electron in a single collision | MeV |
| $k$ | bremsstrahlung photon energy | MeV |
| $z$ | charge number of incident particle |  |
| $Z$ | atomic number of absorber |  |
| $A$ | atomic mass of absorber | g mol$^{-1}$ |
| $K$ | $4\pi N_A r_e^2 m_e c^2$ (Coefficient for $dE/dx$) | 0.307 075 MeV mol$^{-1}$ cm$^2$ |
| $I$ | mean excitation energy | eV (*Nota bene!*) |
| $\delta(\beta\gamma)$ | density effect correction to ionization energy loss |  |
| $\hbar\omega_p$ | plasma energy $\sqrt{4\pi N_e r_e^3}\, m_e c^2/\alpha$ | $\sqrt{\rho \langle Z/A \rangle} \times 28.816$ eV $\longrightarrow \rho$ in g cm$^{-3}$ |
| $N_e$ | electron density | (units of $r_e$)$^{-3}$ |
| $w_j$ | weight fraction of the $j$th element in a compound or mixt. |  |
| $n_j$ | $\propto$ number of $j$th kind of atoms in a compound or mixture |  |
| $X_0$ | radiation length | g cm$^{-2}$ |
| $E_c$ | critical energy for electrons | MeV |
| $E_{\mu c}$ | critical energy for muons | GeV |
| $E_s$ | scale energy $\sqrt{4\pi/\alpha}\, m_e c^2$ | 21.2052 MeV |
| $R_M$ | Molière radius | g cm$^{-2}$ |

## 34.2 Electronic energy loss by heavy particles

### 34.2.1 Moments and cross sections

The electronic interactions of fast charged particles with speed $v = \beta c$ occur in *single collisions with energy losses* $W$ [1], leading to ionization, atomic, or collective excitation. Most frequently the energy losses are small (for 90% of all collisions the energy losses are less than 100 eV). In thin absorbers few collisions will take place and the total energy loss will show a large variance [1]; also see Sec. 34.2.9 below. For particles with charge $ze$ more massive than electrons ("heavy particles"), scattering from free electrons is adequately described by the Rutherford differential cross section [2,3].

$$\frac{d\sigma_R(W;\beta)}{dW} = \frac{2\pi r_e^2 m_e c^2 z^2}{\beta^2} \frac{(1 - \beta^2 W/W_{\max})}{W^2} , \tag{34.1}$$

where $W_{\max}$, the maximum energy transfer possible in a single collision, is discussed below. It differs from the classical cross section by the factor $(1 - \beta^2 W/W_{\max})$, which arises when the spin of the target electrons is taken into account.

Bethe's original theory applied only to energies above which atomic effects are not important. The free-electron cross section (Eq. (34.1)) was used to extend the cross section to $W_{\max}$. This free-electron approximation is not valid if $W$ is not large compared to electron binding energies. For this energy regime Bethe [4,5] used "Born Theorie" to obtain the differential cross section

$$\frac{d\sigma_B(W;\beta)}{dW} = \frac{d\sigma_R(W,\beta)}{dW} B(W) . \tag{34.2}$$

Electronic binding is accounted for by the correction factor $B(W)$. Examples of $B(W)$ and $d\sigma_B/dW$ can be seen in Figs. 5 and 6 of Ref. [1]. For a given material, the correction results in introducing an *effective ionization energy* $I$ "which is a geometric average of the excitation energies of the medium weighed by the corresponding oscillator strength." [6]. The nontrivial task of finding these values is discussed in Sec. 34.2.4.

At high energies the stopping power is further modified by polarization of the medium, and this "density effect," discussed in Sec. 34.2.5, must also be included.

The mean number of collisions with energy loss between $W$ and $W+dW$ occurring in a distance $\delta x$ is $N_e \delta x \, (d\sigma/dW) dW$, where $d\sigma(W;\beta)/dW$, where the cross section is the Rutherford formula if free electrons can be assumed and the Bethe form where binding energy is important. It is convenient to define the moments

$$M_j(\beta) = N_e \delta x \int W^j \frac{d\sigma(W;\beta)}{dW} dW , \tag{34.3}$$

so that $M_0$ is the mean number of collisions in $\delta x$, $M_1$ is the mean energy loss in $\delta x$, $(M_2 - M_1)^2$ is the variance, *etc.* The number of collisions is Poisson-distributed with mean $M_0$. $N_e$ is either measured in electrons/g ($N_e = N_A Z/A$) or electrons/cm$^3$ ($N_e = N_A \rho Z/A$). The former is used throughout this chapter, since quantities of interest ($dE/dx$, $X_0$, *etc.*) vary smoothly with composition when there is no density dependence.

### 34.2.2 Maximum energy transfer to an electron in a single collision

For a point-like particle with mass $M \gg m_e$,

$$W_{\max} = \frac{2 m_e c^2 \beta^2 \gamma^2}{1 + 2\gamma m_e/M + (m_e/M)^2} . \tag{34.4}$$

In older references [2,9] the "low-energy" approximation $W_{\max} = 2 m_e c^2 \beta^2 \gamma^2$, valid for $2\gamma m_e \ll M$, is often implicit. For a pion in copper, the error thus introduced into $dE/dx$ is greater than 6% at 100 GeV. For $2\gamma m_e \gg M$, $W_{\max} = M c^2 \beta^2 \gamma$.

At energies of order 100 GeV, the maximum 4-momentum transfer to the electron can exceed 1 GeV/$c$, where hadronic structure effects modify the cross sections. This problem has been investigated by J.D. Jackson [10], who concluded that for incident hadrons (but not for large nuclei) corrections to $dE/dx$ are negligible below energies where radiative effects dominate. While the cross section for rare hard collisions is modified, the average stopping power, dominated by many softer collisions, is almost unchanged.

> **Figure 34.1** *(PDF p. 4)*
> Original caption: "Mass stopping power ($dE/dx$) for positive muons in copper as a function of $\beta\gamma = p/Mc$ over nine orders of magnitude in momentum (12 orders of magnitude in kinetic energy). Solid curves indicate the total stopping power. Data below the break at $\beta\gamma \approx 0.1$ are taken from ICRU 49 [6] assuming only $\beta$ dependence, and data at higher energies are from [7]. Vertical bands indicate boundaries between different approximations discussed in the text. The short dotted lines labeled '$\mu^-$' illustrate the 'Barkas effect,' the dependence of stopping power on projectile charge at very low energies [8]. $dE/dx$ in the radiative region is not simply a function of $\beta$."
> Description: Log-log plot of mass stopping power (in MeV cm$^2$/g) versus $\beta\gamma$ from $10^{-3}$ to $10^5$, with auxiliary muon-momentum axes spanning MeV/$c$ to TeV/$c$. The total stopping power curve falls steeply through Lindhard-Scharff and Andersen-Ziegler regimes, dips through a broad minimum around $\beta\gamma \sim 3$ in the Bethe region, rises slowly, and turns up sharply in the radiative region beyond the muon critical energy $E_{\mu c}$. Vertical shaded bands separate the approximation regimes; a dashed "Without $\delta$" curve shows the relativistic rise absent the density-effect correction.

### 34.2.3 Stopping power at intermediate energies

The mean rate of energy loss by moderately relativistic charged heavy particles is well described by the "Bethe equation" [2,4,5,9],

$$\left\langle -\frac{dE}{dx} \right\rangle = K z^2 \frac{Z}{A} \frac{1}{\beta^2} \left[ \frac{1}{2} \ln \frac{2 m_e c^2 \beta^2 \gamma^2 W_{\max}}{I^2} - \beta^2 - \frac{\delta(\beta\gamma)}{2} \right] . \tag{34.5}$$

Eq. (34.5) is valid in the region $0.1 \lesssim \beta\gamma \lesssim 1000$ with an accuracy of a few percent. At $\beta\gamma \sim 0.1$ the projectile speed is comparable to atomic electron "speed," and at $\beta\gamma \sim 1000$ radiative effects begin to be important (Sec. 34.6). Both limits are $Z$ dependent. A minor dependence on $M$ at high energies is introduced through $W_{\max}$, but for all practical purposes the stopping power in a given material is a function of $\beta$ alone. Small corrections are discussed in Sec. 34.2.6.[^1]$^,$[^2]

This is the *mass stopping power*; with the symbol definitions and values given in Table 34.1, the units are MeV g$^{-1}$ cm$^2$. As can be seen from Fig. 34.2, $dE/dx$ defined in this way is about the same for most materials, decreasing slowly with $Z$. The linear stopping power, in MeV/cm, is $\rho \, dE/dx$, where $\rho$ is the density in g/cm$^3$.

[^1]: For incident spin 1/2 particles, $(W_{\max}/E)^2/4$ is included in the square brackets. Although this correction is within the uncertainties in the total stopping power, its inclusion avoids a systematic bias.
[^2]: In this section, "$dE/dx$" will be understood to mean the mass stopping power "$\langle -dE/dx \rangle$."

The stopping power at first falls as $1/\beta^\alpha$ where $\alpha \approx 1.7$–$1.5$, decreasing with increasing $Z$, and reaches a broad minimum at $\beta\gamma = 3.8$–$3.0$ as $Z$ rises from 6 to 82. It then inexorably rises as the argument of the logarithmic term increases. Two independent mechanisms contribute. Two thirds of the rise is produced by the explicit $\beta^2 \gamma^2$ dependence through the relativistic flattening and extension of the particle's electric field. Rather than producing ionization at greater and greater distances, the field polarizes the medium, cancelling the increase in the logarithmic term at high energies. This is taken into account by the density-effect correction $\delta(\beta\gamma)$. The other third is introduced by the $\beta^2 \gamma$ dependence of $W_{\max}$, the maximum possible energy transfer to a recoil electron. "Hard collision" events increasingly extend the tail of the energy loss distribution, increasing the mean but with little effect on the position of the maximum, the most probable energy loss.

Few concepts in high-energy physics are as misused as $dE/dx$, since the mean is weighted by rare events with large single-collision energy losses. Even with samples of hundreds of events in a typical detector, the mean energy loss cannot be obtained dependably. Far better and more easily measured is the most probable energy loss, discussed in Sec. 34.2.9. The most probable energy loss in a typical detector is considerably smaller than the mean given by the Bethe equation. It does not continue to rise with the mean stopping power, but approaches a "Fermi plateau."

In analysing TPC data (Sec. 35.6.4), the same end is often accomplished by using a restricted energy loss, the mean of 50%–70% of the samples with the smallest signals as the estimator.

Although it must be used with cautions and caveats, $dE/dx$ as described in Eq. (34.5) still forms the basis of much of our understanding of energy loss by charged particles. Extensive tables are available [6,7] and pdg.lbl.gov/current/AtomicNuclearProperties/.

For heavy projectiles, like ions, additional terms are required to account for higher-order photon coupling to the target, and to account for the finite target radius. These can change $dE/dx$ by a factor of two or more for the heaviest nuclei in certain kinematic regimes [11].

The function as computed for muons on copper is shown as the "Bethe" region of Fig. 34.1. Mean energy loss behavior below this region is discussed in Sec. 34.2.6, and the radiative effects at high energy are discussed in Sec. 34.6. Only in the Bethe region is it a function of $\beta$ alone; the mass dependence is more complicated elsewhere. The stopping power in several other materials is shown in Fig. 34.2. Except in hydrogen, particles with the same speed have similar rates of energy loss in different materials, although there is a slow decrease in the rate of energy loss with increasing $Z$. The qualitative behavior difference at high energies between a gas (He in the figure) and the other materials shown in the figure is due to the density-effect correction, $\delta(\beta\gamma)$, discussed in Sec. 34.2.5. The stopping power functions are characterized by broad minima whose position drops from $\beta\gamma = 3.5$ to 3.0 as $Z$ goes from 7 to 100. The values of minimum ionization as a function of atomic number are shown in Fig. 34.3.

In practical cases, most relativistic particles (*e.g.*, cosmic-ray muons) have mean energy loss rates close to the minimum; they are "minimum-ionizing particles," or mip's.

Eq. (34.5) may be integrated to find the total (or partial) "continuous slowing-down approximation" (CSDA) range $R$ for a particle which loses energy only through ionization and atomic excitation. Since $dE/dx$ depends only on $\beta$, $R/M$ is a function of $E/M$ or $pc/M$. In practice, range is a useful concept only for low-energy hadrons ($R \lesssim \lambda_I$, where $\lambda_I$ is the nuclear interaction length), and for muons below a few hundred GeV (above which radiative effects dominate). Fig. 34.4 shows $R/M$ as a function of $\beta\gamma$ ($= p/Mc$) for a variety of materials.

The mass scaling of $dE/dx$ and range is valid for the electronic losses described by the Bethe equation, but not for radiative losses.

> **Figure 34.2** *(PDF p. 6)*
> Original caption: "Mean energy loss rate in liquid (bubble chamber) hydrogen, gaseous helium, carbon, aluminum, iron, tin, and lead. Radiative effects, relevant for muons and pions, are not included. These become significant for muons in iron for $\beta\gamma \gtrsim 1000$, and at lower momenta for muons in higher-$Z$ absorbers. See Fig. 34.23."
> Description: Log-log plot of $\langle -dE/dx \rangle$ in MeV g$^{-1}$ cm$^2$ versus $\beta\gamma = p/Mc$ from 0.1 to 10 000, with auxiliary muon, pion, and proton momentum axes. Seven curves for H$_2$ liquid (highest), He gas, C, Al, Fe, Sn, and Pb (lowest) all show a broad minimum near $\beta\gamma \sim 3$ and a slow relativistic rise. The H$_2$ and He gas curves rise more steeply at high $\beta\gamma$ than the denser solids, illustrating the density-effect suppression in condensed media.

### 34.2.4 Mean excitation energy

"The determination of the mean excitation energy is the principal non-trivial task in the evaluation of the Bethe stopping-power formula" [15]. Recommended values have varied substantially with time. Estimates based on experimental stopping-power measurements for protons, deuterons, and alpha particles and on oscillator-strength distributions and dielectric-response functions were given in ICRU 49 [6]. See also ICRU 37 [12]. These values, shown in Fig. 34.5, have since been widely used. Machine-readable versions can also be found [16].

> **Figure 34.3** *(PDF p. 7)*
> Original caption: "Mass stopping power at minimum ionization for the chemical elements. The straight line is fitted for $Z > 6$. A simple functional dependence on $Z$ is not to be expected, since $dE/dx$ also depends on other variables."
> Description: Semi-log plot of $\langle -dE/dx \rangle_{\min}$ in MeV g$^{-1}$ cm$^2$ versus atomic number $Z$ from 1 to 100. Solid plus markers indicate solid elements and open red circles indicate gaseous elements; the points decrease from about 2 at low $Z$ to roughly 1.1 at uranium, and a fitted line $2.35 - 0.28 \ln(Z)$ tracks the trend for $Z > 6$. Hydrogen is annotated as outliers (H$_2$ gas: 4.10, H$_2$ liquid: 3.97).

### 34.2.5 Density effect

As the particle energy increases, its electric field flattens and extends, so that the distant-collision contribution to the logarithmic term in Eq. (34.5) increases as $\beta^2 \gamma^2$. However, real media become polarized, limiting the field extension and effectively truncating this part of the logarithmic rise [2,3,6,17,18]. At very high energies,

$$\delta(\beta\gamma)/2 \to \ln(\hbar\omega_p/I) + \ln \beta\gamma - 1/2 , \tag{34.6}$$

where $\delta(\beta\gamma)/2$ is the density effect correction introduced in Eq. (34.5) and $\hbar\omega_p$ is the plasma energy defined in Table 34.1. A comparison with Eq. (34.5) shows that $dE/dx$ then grows as $\ln T_{\max}$ rather than $\ln \beta^2 \gamma^2 T_{\max}$, and that the mean excitation energy $I$ is replaced by the plasma energy $\hbar\omega_p$. An example of the ionization stopping power as calculated with and without the density effect correction is shown in Fig. 34.1. Since the plasma frequency scales as the square root of the electron density, the correction is much larger for a liquid or solid than for a gas, as is illustrated in Fig. 34.2.

> **Figure 34.4** *(PDF p. 8)*
> Original caption: "Range of heavy charged particles in liquid (bubble chamber) hydrogen, helium gas, carbon, iron, and lead. For example: For a $K^+$ whose momentum is 700 MeV/$c$, $\beta\gamma = 1.42$. For lead we read $R/M \approx 396$, and so the range is 195 g cm$^{-2}$ (17 cm)."
> Description: Log-log plot of $R/M$ in g cm$^{-2}$ GeV$^{-1}$ versus $\beta\gamma = p/Mc$ from 0.1 to 100, with auxiliary muon, pion, and proton momentum axes. Five curves are drawn for C, Fe, Pb, H$_2$ liquid, and He gas; all rise smoothly and approximately as a power law, with the heavier absorbers (C, Fe, Pb) clustered together at higher $R/M$ and H$_2$ liquid lying lowest.

> **Figure 34.5** *(PDF p. 7, referenced in §34.2.4)*
> Original caption: "Mean excitation energies (divided by $Z$) as adopted by the ICRU [12]. Those based on experimental measurements are shown by symbols with error flags; the interpolated values are simply joined. The grey point is for liquid H$_2$; the black point at 19.2 eV is for H$_2$ gas. The open circles show more recent determinations by Bichsel [13]. The dash-dotted curve is from the approximate formula of Barkas [14] used in early editions of this Review."
> Description: Plot of $I/Z$ (mean excitation energy per atomic number, in eV) versus $Z$, comparing ICRU-adopted values (with measurement error flags), interpolated joining curve, more recent Bichsel determinations (open circles), and the older Barkas approximation (dash-dotted curve). Hydrogen points are highlighted separately for liquid and gas phases.

The density effect correction is usually computed using Sternheimer's parameterization [17]:

$$\delta(\beta\gamma) = \begin{cases} 2(\ln 10) x - \overline{C} & \text{if } x \geq x_1 ; \\ 2(\ln 10) x - \overline{C} + a(x_1 - x)^k & \text{if } x_0 \leq x < x_1 ; \\ 0 & \text{if } x < x_0 \text{ (nonconductors)}; \\ \delta_0 \, 10^{2(x - x_0)} & \text{if } x < x_0 \text{ (conductors)} \end{cases} \tag{34.7}$$

Here $x = \log_{10} \beta\gamma = \log_{10}(p/Mc)$. $\overline{C}$ (the negative of the $C$ used in Ref. [17]) is obtained by equating the high-energy case of Eq. (34.7) with the limit given in Eq. (34.6). The other parameters are adjusted to give a best fit to the results of detailed calculations for momenta below $Mc \exp(x_1)$. For nonconductors the correction is 0 below $\beta\gamma = 10^{x_0}$, corresponding to 100–200 MeV for pions and 1–2 GeV for protons. For conductors it decreases rapidly below this point. Parameters for the elements and nearly 200 compounds and mixtures of interest are published in a variety of places, notably in Ref. [18]. A recipe for finding the coefficients for nontabulated materials is given by Sternheimer and Peierls [19] and is summarized in Ref. [7].

The remaining relativistic rise comes from the $\beta^2 \gamma$ growth of $W_{\max}$, which in turn is due to (rare) large energy transfers to a few electrons. When these events are excluded, the energy deposit in an absorbing layer approaches a constant value, the Fermi plateau (see Sec. 34.2.8 below). At even higher energies (*e.g.*, $> 332$ GeV for muons in iron, and at a considerably higher energy for protons in iron), radiative effects are more important than ionization losses. These are especially relevant for high-energy muons, as discussed in Sec. 34.6.

### 34.2.6 Energy loss at low energies

The theory of energy loss by ionization and excitation as given by Bethe is based on a first-order Born approximation. It assumes free electrons, and should be valid when the projectile's speed is large compared to that of the atomic electrons. This presents a problem at low energies, where $W_{\max}$ is less than the K shell binding energy. However, Mott showed that the Born approximation can be applied at energies much smaller than atomic binding energies [20]; the incident particle can be treated by classical mechanics since its wavelength is shorter than atomic dimensions. The Born method is actually better justified when its speed is not large compared to the K electron speed [5].

Higher-order corrections must still be made to extend the Bethe equation (Eq. (34.5)) to low energies. An improved approximation for the terms in the square brackets of Eq. (34.5) at low energies is obtained with

$$ L(\beta) = L_a(\beta) - \frac{C(\beta)}{Z} + zL_1(\beta) + z^2 L_2(\beta) \,. \tag{34.8}$$

Here $L_a$ is the square-bracketed terms of Eq. (34.5), $C/Z$ is the sum of shell corrections and $zL_1$ and $z^2 L_2$ are Barkas and Bloch correction terms [6, 21]. With these corrections, the Bethe treatment is accurate to about 1% down to $\beta \approx 0.05$, or about 1 MeV for protons (0.13 MeV for muons). Values of $L_a$, $C/Z$, $L_1$, and $L_2$ in the range $T = 0.3\text{--}30$ MeV for a proton traversing aluminum can be found in Table I of Ref. [21].

*Shell correction* $-C/Z$. As the speed of the projectile decreases, the contribution to the stopping power from K shell electrons decreases, and at even lower velocities contributions from L and higher shells further reduce it. The correction $(C_K + C_L + \ldots)/Z$ is should be included in the square brackets of Eq. (34.5). It is calculated and tabulated (for a few common materials) in a number of places; Refs. [6,12,21] are especially useful. As an example, the shell correction for a 30 MeV proton traversing aluminum is 0.6%, increasing to 9.9% as the proton's energy decreases to 0.3 MeV.

*Barkas correction* $zL_1$. Qualitatively, one might imagine an atom's electron cloud slightly recoiling at the approach of a negative projectile and being attracted toward an approaching positive projectile. Hence the stopping power for negative particles should be slightly smaller than the stopping power for positive particles. In a 1956 paper, Barkas et al. noted that negative pions possibly had a longer range than positive pions [8]. The effect has been measured for a number of negative/positive particle pairs, and more recently in detailed studies with antiprotons at the CERN LEAR facility [22]. Since no complete theory exists, an empirical approach is necessary. A 1972 harmonic-oscillator model by Ashley et al. [23] is often used; it has two parameters determined by experimental data. For protons in aluminum, $L_1/L_a$ is less than 0.1% at 30 MeV, but increases to 17% as $T$ decreases to 0.3 MeV. This correction is indicated in Fig. 34.1.

*Bloch correction* $z^2 L_2$. Bloch's extension of Bethe's theory introduced a low-energy correction that takes account of perturbations of the atomic wave functions. The form obtained by Lindhard and Sørensen [11] is used e.g. in Refs. [6, 21]. For protons in aluminum, $-L_2/L_|$ is less than 0.3% at 3.0 MeV, but rises to 7% when the energy has fallen to 0.3 MeV.

For the interval $0.01 < \beta < 0.05$ there is no satisfactory theory. For protons, one usually relies on the phenomenological fitting formulae developed by Andersen and Ziegler [6, 24]. As tabulated in ICRU 49 [6], the nuclear plus electronic proton stopping power in copper is 113 MeV cm$^2$ g$^{-1}$ at $T = 10$ keV ($\beta\gamma = 0.005$), rises to a maximum of 210 MeV cm$^2$ g$^{-1}$ at $T \approx 120$ keV ($\beta\gamma = 0.016$), then falls to 118 MeV cm$^2$ g$^{-1}$ at $T = 1$ MeV ($\beta\gamma = 0.046$). Above 0.5–1.0 MeV the corrected Bethe theory is adequate.

For particles moving more slowly than $\approx 0.01c$ (more or less the speed of the outer atomic electrons), Lindhard has been quite successful in describing electronic stopping power, which is proportional to $\beta$ [25]. Finally, we note that at even lower energies, e.g., for protons of less than several hundred eV, non-ionizing nuclear recoil energy loss dominates the total energy loss [6,25,26].

### 34.2.7 Energetic knock-on electrons ($\delta$ rays)

The distribution of secondary electrons with kinetic energies $T \gg I$ is [2]

$$ \frac{d^2 N}{dT\,dx} = \frac{1}{2} K z^2 \frac{Z}{A} \frac{1}{\beta^2} \frac{F(T)}{T^2} \tag{34.9}$$

for $I \ll T \le W_{\max}$, where $W_{\max}$ is given by Eq. (34.4). Here $\beta$ is the speed of the primary particle. The factor $F$ is spin-dependent, but is about unity for $T \ll W_{\max}$. For spin-0 particles $F(T) = (1 - \beta^2 T/W_{\max})$; forms for spins 1/2 and 1 are also given by Rossi [2] (Sec. 2.3, Eqs. 7 and 8). Additional formulae are given in [27]. Equation Eq. (34.9) is inaccurate for $T$ close to $I$ [28].

$\delta$ rays of even modest energy are rare. For a $\beta \approx 1$ particle, for example, on average only one collision with $T_e > 10$ keV will occur along a path length of 90 cm of argon gas [1].

A $\delta$ ray with kinetic energy $T_e$ and corresponding momentum $p_e$ is produced at an angle $\theta$ given by

$$ \cos\theta = (T_e/p_e)(p_{\max}/W_{\max}) \,, \tag{34.10}$$

where $p_{\max}$ is the momentum of an electron with the maximum possible energy transfer $W_{\max}$.

### 34.2.8 Restricted energy loss rates for relativistic ionizing particles

Further insight can be obtained by examining the mean energy deposit by an ionizing particle when energy transfers are restricted to $T \le W_{\text{cut}} \le W_{\max}$. The restricted energy loss rate is

$$ -\left.\frac{dE}{dx}\right|_{T<W_{\text{cut}}} = K z^2 \frac{Z}{A} \frac{1}{\beta^2} \left[ \frac{1}{2} \ln \frac{2 m_e c^2 \beta^2 \gamma^2 W_{\text{cut}}}{I^2} - \frac{\beta^2}{2}\left(1 + \frac{W_{\text{cut}}}{W_{\max}}\right) - \frac{\delta}{2} \right] \,. \tag{34.11}$$

This form approaches the normal Bethe function (Eq. (34.5)) as $W_{\text{cut}} \to W_{\max}$. It can be verified that the difference between Eq. (34.5) and Eq. (34.11) is equal to $\int_{W_{\text{cut}}}^{W_{\max}} T (d^2 N/dT\,dx)\,dT$, where $d^2 N/dT\,dx$ is given by Eq. (34.9).

Since $W_{\text{cut}}$ replaces $W_{\max}$ in the argument of the logarithmic term of Eq. (34.5), the $\beta\gamma$ term producing the relativistic rise in the close-collision part of $dE/dx$ is replaced by a constant, and $|dE/dx|_{T<W_{\text{cut}}}$ approaches the constant "Fermi plateau." (The density effect correction $\delta$ eliminates the explicit $\beta\gamma$ dependence produced by the distant-collision contribution.) This behavior is illustrated in Fig. 34.6, where restricted loss rates for two examples of $W_{\text{cut}}$ are shown in comparison with the full Bethe $dE/dx$ and the Landau-Vavilov most probable energy loss (to be discussed in Sec. 34.2.9 below).

"Restricted energy loss" is cut at the total mean energy, not the single-collision energy above $W_{\text{cut}}$ It is of limited use. The most probable energy loss, discussed in the next Section, is far more useful in situations where single-particle energy loss is observed.

### 34.2.9 Fluctuations in energy loss

For detectors of moderate thickness $x$ (e.g. scintillators or LAr cells),[^3] the energy loss probability distribution $f(\Delta; \beta\gamma, x)$ is adequately described by the highly-skewed Landau (or Landau-Vavilov) distribution [29, 30].

[^3]: "Moderate thickness" means $G \lesssim 0.05\text{--}0.1$, where $G$ is given by Rossi Ref. [2], Eq. 2.7(10). It is Vavilov's $\kappa$ [29]. $G$ is proportional to the absorber's thickness, and as such parameterizes the constants describing the Landau distribution. These are fairly insensitive to thickness for $G \lesssim 0.1$, the case for most detectors.

> **Figure 34.6** *(PDF p. 12)*
> Original caption: "Bethe $dE/dx$, two examples of restricted energy loss, and the Landau most probable energy per unit thickness in silicon. The change of $\Delta_p/\text{x}$ with thickness $x$ illustrates its $a \ln x + b$ dependence. Minimum ionization ($dE/dx|_{\min}$) is 1.664 MeV g$^{-1}$ cm$^2$. Radiative losses are excluded. The incident particles are muons."
> Description: Log-log plot of stopping power in silicon (MeV g$^{-1}$ cm$^2$) versus muon kinetic energy from 0.1 GeV to 1 TeV. The full Bethe $dE/dx$ curve rises after the minimum due to the relativistic rise, while two restricted energy loss curves (with $T_{\text{cut}} = 10\,dE/dx|_{\min}$ and $T_{\text{cut}} = 2\,dE/dx|_{\min}$) flatten into Fermi plateaus. Three Landau-Vavilov-Bichsel $\Delta_p/x$ curves for silicon thicknesses 1600, 320, and 80 µm sit lower still and exhibit a mild $a \ln x + b$ thickness dependence.

The most probable energy loss is [31][^4]

$$ \Delta_p = \xi \left[ \ln \frac{2 m_e c^2 \beta^2 \gamma^2}{I} + \ln \frac{\xi}{I} + j - \beta^2 - \delta(\beta\gamma) \right] \,, \tag{34.12}$$

where $\xi = (K/2) \langle Z/A \rangle z^2 (x/\beta^2)$ MeV for a detector with a thickness $x$ in g cm$^{-2}$, and $j = 0.200$ [31].[^5] While $dE/dx$ is independent of thickness, $\Delta_p/x$ scales as $a \ln x + b$. The density correction $\delta(\beta\gamma)$ was not included in Landau's or Vavilov's work, but it was later included by Bichsel [31]. The high-energy behavior of $\delta(\beta\gamma)$ (Eq. (34.6)) is such that

$$ \Delta_p \xrightarrow[\beta\gamma \gtrsim 100]{} \xi \left[ \ln \frac{2 m_e c^2 \xi}{(\hbar \omega_p)^2} + j \right] \,. \tag{34.13}$$

Thus the Landau-Vavilov most probable energy loss, like the restricted energy loss, reaches a Fermi plateau. The Bethe $dE/dx$ and Landau-Vavilov-Bichsel $\Delta_p/x$ in silicon are shown as a function of muon energy in Fig. 34.6. The energy deposit in the 1600 µm case is roughly the same as in a 3 mm thick plastic scintillator.

[^4]: Practical calculations can be expedited by using the tables of $\delta$ and $\beta$ from the text versions of the muon energy loss tables to be found at pdg.lbl.gov/curremt/AtomicNuclearProperties.

[^5]: Rossi [2], Talman [32], and others give somewhat different values for $j$. The most probable loss is not sensitive to its value.

The distribution function for the energy deposit by a 10 GeV muon going through a detector of about this thickness is shown in Fig. 34.7. In this case the most probable energy loss is 62% of the mean ($M_1(\langle\Delta\rangle)/M_1(\infty)$). Folding in experimental resolution displaces the peak of the distribution, usually toward a higher value. 90% of the collisions ($M_1(\langle\Delta\rangle)/M_1(\infty)$) contribute to energy deposits below the mean. It is the very rare high-energy-transfer collisions, extending to $W_{\max}$ at several GeV, that drives the mean into the tail of the distribution. The large weight of these rare events makes the mean of an experimental distribution consisting of a few hundred events subject to large fluctuations and sensitive to cuts. *The mean of the energy loss given by the Bethe equation, Eq. (34.5), is thus ill-defined experimentally and is not useful for describing energy loss by single particles*.[^6] It rises as $\ln \gamma$ because $W_{\max}$ increases as $\gamma$ at high energies. *The most probable energy loss should be used*.

[^6]: It does find application in dosimetry, where only bulk deposit is relevant.

> **Figure 34.7** *(PDF p. 13)*
> Original caption: "Electronic energy deposit distribution for a 10 GeV muon traversing 1.7 mm of silicon, the stopping power equivalent of about 0.3 cm of PVT-based scintillator [1, 13, 33]. The Landau-Vavilov function (dot-dashed) uses a Rutherford cross section without atomic binding corrections but with a kinetic energy transfer limit of $W_{\max}$. The solid curve was calculated using Bethe-Fano theory. $M_0(\Delta)$ and $M_1(\Delta)$ are the cumulative 0th moment (mean number of collisions) and 1st moment (mean energy loss) in crossing the silicon. (See Sec. 34.2.1). The fwhm of the Landau-Vavilov function is about $4\xi$ for detectors of moderate thickness. $\Delta_p$ is the most probable energy loss, and $\langle\Delta\rangle$ divided by the thickness is the Bethe $dE/dx$."
> Description: Plot of $f(\Delta)$ versus electronic energy loss $\Delta$ from 0.4 to 1.0 MeV for a 10 GeV muon traversing 1.7 mm of silicon, comparing the Landau-Vavilov dot-dashed curve with the Bichsel Bethe-Fano solid curve. Both peak near the most probable value $\Delta_p \approx 0.5$ MeV with a long high-energy tail extending past the mean $\langle\Delta\rangle$. Overlaid are the cumulative moment ratios $M_0(\Delta)/M_0(\infty)$ and $M_1(\Delta)/M_1(\infty)$ on a right-hand axis, showing how the bulk of collisions and energy contribute below the mean.

A practical example: For muons traversing 0.25 inches (0.64 cm) of PVT (polyvinyltolulene) based plastic scintillator, the ratio of the most probable $E$ loss rate to the mean loss rate via the Bethe equation is $[0.69, 0.57, 0.49, 0.42, 0.38]$ for $T_\mu = [0.01, 0.1, 1, 10, 100]$ GeV. Radiative losses add less than 0.5% to the total mean energy deposit at 10 GeV, but add 7% at 100 GeV. The most probable $E$ loss rate rises slightly beyond the minimum ionization energy, then is essentially constant.

The Landau distribution fails to describe energy loss in thin absorbers such as gas TPC cells [1] and Si detectors [31], as can be seen e.g. in Fig. 1 of Ref. [1] for an argon-filled TPC cell. Also see Talman [32]. While $\Delta_p/x$ may be calculated adequately with Eq. (34.12), the distributions are significantly wider than the Landau width $w = 4\xi$ Ref. [31], Fig. 15. Examples for 500 MeV pions incident on thin silicon detectors are shown in Fig. 34.8. For very thick absorbers the distribution is less skewed but never approaches a Gaussian.

> **Figure 34.8** *(PDF p. 14)*
> Original caption: "Straggling functions in silicon for 500 MeV pions, normalized to unity at the most probable value $\Delta_p/x$. The width $w$ is the full width at half maximum."
> Description: Normalized straggling functions $f(\Delta/x)$ for 500 MeV pions in silicon, plotted against $\Delta/x$ in eV/µm (lower axis) and MeV g$^{-1}$ cm$^2$ (upper axis). Four curves correspond to silicon thicknesses 640, 320, 160, and 80 µm; thinner absorbers produce broader, more asymmetric distributions whose peaks shift to lower $\Delta/x$. The full width at half maximum $w$ and the most probable value $\Delta_p/x$ are marked, with an arrow indicating the much higher mean energy loss rate well into the tail.

The most probable energy loss, scaled to the mean loss at minimum ionization, is shown in Fig. 34.9 for several silicon detector thicknesses.

### 34.2.10 Energy loss in mixtures and compounds

A mixture or compound can be thought of as made up of thin layers of pure elements in the right proportion (Bragg additivity). In this case,

$$ \left\langle \frac{dE}{dx} \right\rangle = \sum_j w_j \left\langle \frac{dE}{dx} \right\rangle_j \,, \tag{34.14}$$

where $dE/dx|_j$ is the mean rate of energy loss (in MeV g$^{-1}$ cm$^2$) in the $j$th element. Eq. (34.5) can be inserted into Eq. (34.14) to find expressions for $\langle Z/A \rangle$, $\langle I \rangle$, and $\langle \delta \rangle$; for example, $\langle Z/A \rangle = \sum w_j Z_j/A_j = \sum n_j Z_j / \sum n_j A_j$. However, $\langle I \rangle$ as defined this way is an underestimate, because in a compound electrons are more tightly bound than in the free elements, and $\langle \delta \rangle$ as calculated this way has little relevance, because it is the electron density that matters. If possible, one uses the tables given in Refs. [18,34], or the recipes given in [19] (repeated in Ref. [7]), that include effective excitation energies and interpolation coefficients for calculating the density effect correction for the chemical elements and nearly 200 mixtures and compounds. Otherwise, use the recipe for $\delta$ given in Refs. [7, 19], and calculate $\langle I \rangle$ following the discussion in Ref. [15]. (Note the "13%" rule!)

> **Figure 34.9** *(PDF p. 15)*
> Original caption: "Most probable energy loss in silicon, scaled to the mean loss of a minimum ionizing particle, 388 eV/µm (1.66 MeV g$^{-1}$cm$^2$)."
> Description: Plot of the ratio $(\Delta_p/x)/dE/dx|_{\min}$ versus $\beta\gamma = p/m$ from 0.3 to 1000 for four silicon thicknesses (640, 320, 160, 80 µm). Each curve dives steeply at low $\beta\gamma$, reaches a minimum near $\beta\gamma \approx 3\text{--}4$, then climbs gently toward a Fermi plateau; thicker absorbers produce a higher scaled most-probable loss. The plateau values illustrate that $\Delta_p/x$ remains well below the mean $dE/dx$ even at high energies, and the spread between curves makes the $a\ln x + b$ thickness dependence visible.

### 34.2.11 Ionization yields

The Bethe equation describes energy loss via excitation and ionization. Many gaseous detectors (proportional counters or TPCs) or liquid ionization detectors count the number of electrons or positive ions from ionization, rather than the ionization energy. As a further complication, the electron liberated in the initial ionization often has enough energy to ionize other atoms or molecules; this process can happen several times. The number of electron-ion pairs per unit length is typically three or more times the original number. Ion or electron counting is a proxy for a direct $dE/dx$ measurement. Calibrations link the number of observed ions to the traversing particle's $dE/dx$.

The details depend on the gases (or liquids) and the particular detector involved. A useful discussion of the physics is provided in Sec.35.6 of this Review.

## 34.3 Multiple scattering through small angles

A charged particle traversing a medium is deflected by many small-angle scatters. Most of this deflection is due to Coulomb scattering from nuclei as described by the Rutherford cross section. (However, for hadronic projectiles, the strong interactions also contribute to multiple scattering.) For many small-angle scatters the net scattering and displacement distributions are Gaussian via the central limit theorem. Less frequent "hard" scatters produce non-Gaussian tails. These Coulomb scattering distributions are well-represented by the theory of Molière [35]. Accessible discussions are given by Rossi [2] and Jackson [3], and exhaustive reviews have been published by Scott [36] and Motz et al. [37]. Experimental measurements have been published by Bichsel [38] (low energy protons) and by Shen et al. [39] (relativistic pions, kaons, and protons).[^7]

If we define

$$
\theta_0 = \theta^{\text{rms}}_{\text{plane}} = \frac{1}{\sqrt{2}}\,\theta^{\text{rms}}_{\text{space}} \,,
\tag{34.15}
$$

then it is sufficient for many applications to use a Gaussian approximation for the central 98% of the projected angular distribution, with an rms width given by Lynch & Dahl [40]:

$$
\begin{aligned}
\theta_0 &= \frac{13.6\ \text{MeV}}{\beta c p}\, z \, \sqrt{\frac{x}{X_0}} \left[ 1 + 0.088\,\log_{10}\!\left(\frac{x\,z^2}{X_0\,\beta^2}\right) \right] \\
        &= \frac{13.6\ \text{MeV}}{\beta c p}\, z \, \sqrt{\frac{x}{X_0}} \left[ 1 + 0.038\,\ln\!\left(\frac{x\,z^2}{X_0\,\beta^2}\right) \right]
\end{aligned}
\tag{34.16}
$$

Here $p$, $\beta c$, and $z$ are the momentum, speed, and charge number of the incident particle, and $x/X_0$ is the thickness of the scattering medium in radiation lengths (defined below). This takes into account the $p$ and $z$ dependence quite well at small $Z$, but for large $Z$ and small $x$ the $\beta$-dependence is not well represented. Further improvements are discussed in Ref. [40].

Eq. (34.16) describes scattering from a single material, while the usual problem involves the multiple scattering of a particle traversing many different layers and mixtures. Since it is from a fit to a Molière distribution, it is incorrect to add the individual $\theta_0$ contributions in quadrature; the result is systematically too small. It is much more accurate to apply Eq. (34.16) once, after finding $x$ and $X_0$ for the combined scatterer.

> **Figure 34.10** *(PDF p. 16)*
> Original caption: "Quantities used to describe multiple Coulomb scattering. The particle is incident in the plane of the figure."
> Description: A schematic shows a charged particle entering a slab of thickness $x$ from the left and following a wavy trajectory through it. Labeled at the exit are the projected scattering angle $\theta_{\text{plane}}$, the lateral displacement $y_{\text{plane}}$, an intermediate angle $\Psi_{\text{plane}}$, and an arc-length-related quantity $s_{\text{plane}}$, with a half-thickness marker at $x/2$ along the dashed straight-ahead reference line. The figure visualizes the geometric variables that appear in Eqs. (34.19)–(34.22).

The nonprojected (space) and projected (plane) angular distributions are given approximately by [35]

$$
\frac{1}{2\pi\,\theta_0^2}\,\exp\!\left(-\frac{\theta_{\text{space}}^2}{2\,\theta_0^2}\right) d\Omega \,,
\tag{34.17}
$$

$$
\frac{1}{\sqrt{2\pi}\,\theta_0}\,\exp\!\left(-\frac{\theta_{\text{plane}}^2}{2\,\theta_0^2}\right) d\theta_{\text{plane}} \,,
\tag{34.18}
$$

where $\theta$ is the deflection angle. In this approximation, $\theta_{\text{space}}^2 \approx (\theta_{\text{plane},x}^2 + \theta_{\text{plane},y}^2)$, where the $x$ and $y$ axes are orthogonal to the direction of motion, and $d\Omega \approx d\theta_{\text{plane},x}\,d\theta_{\text{plane},y}$. Deflections into $\theta_{\text{plane},x}$ and $\theta_{\text{plane},y}$ are independent and identically distributed. Fig. 34.10 shows these and other quantities sometimes used to describe multiple Coulomb scattering. They are

$$
\psi^{\text{rms}}_{\text{plane}} = \frac{1}{\sqrt{3}}\,\theta^{\text{rms}}_{\text{plane}} = \frac{1}{\sqrt{3}}\,\theta_0 \,,
\tag{34.19}
$$

$$
y^{\text{rms}}_{\text{plane}} = \frac{1}{\sqrt{3}}\,x\,\theta^{\text{rms}}_{\text{plane}} = \frac{1}{\sqrt{3}}\,x\,\theta_0 \,,
\tag{34.20}
$$

$$
s^{\text{rms}}_{\text{plane}} = \frac{1}{4\sqrt{3}}\,x\,\theta^{\text{rms}}_{\text{plane}} = \frac{1}{4\sqrt{3}}\,x\,\theta_0 \,.
\tag{34.21}
$$

All the quantitative estimates in this section apply only in the limit of small $\theta^{\text{rms}}_{\text{plane}}$ and in the absence of large-angle scatters. The random variables $s$, $\psi$, $y$, and $\theta$ in a given plane are correlated. Obviously, $y \approx x\psi$. In addition, $y$ and $\theta$ have the correlation coefficient $\rho_{y\theta} = \sqrt{3}/2 \approx 0.87$. For Monte Carlo generation of a joint $(y_{\text{plane}}, \theta_{\text{plane}})$ distribution, or for other calculations, it may be most convenient to work with independent Gaussian random variables $(z_1, z_2)$ with mean zero and variance one, and then set

$$
\begin{aligned}
y_{\text{plane}} &= z_1\,x\,\theta_0\,(1 - \rho_{y\theta}^2)^{1/2}/\sqrt{3} + z_2\,\rho_{y\theta}\,x\,\theta_0/\sqrt{3} & (34.22\text{a}) \\
                 &= z_1\,x\,\theta_0/\sqrt{12} + z_2\,x\,\theta_0/2 \,; & (34.22\text{b}) \\
\theta_{\text{plane}} &= z_2\,\theta_0 \,. & (34.22\text{c})
\end{aligned}
$$

Note that the second term for $y_{\text{plane}}$ equals $x\,\theta_{\text{plane}}/2$ and represents the displacement that would have occurred had the deflection $\theta_{\text{plane}}$ all occurred at the single point $x/2$.

For heavy ions the multiple Coulomb scattering has been measured and compared with various theoretical distributions [41].

[^7]: Shen et al.'s measurements show that Bethe's simpler methods of including atomic electron effects agrees better with experiment than does Scott's treatment.

## 34.4 Photon and electron interactions in matter

At low energies electrons and positrons primarily lose energy by ionization, although other processes (Møller scattering, Bhabha scattering, e+ annihilation) contribute, as shown in Fig. 34.11. While ionization loss rates rise logarithmically with energy, bremsstrahlung losses rise nearly linearly (fractional loss is nearly independent of energy), and dominates above the critical energy (Sec. 34.4.4 below), a few tens of MeV in most materials.

### 34.4.1 Collision energy losses by e±

Stopping power differs somewhat for electrons and positrons, and both differ from stopping power for heavy particles because of the kinematics, spin, charge, and the identity of the incident electron with the electrons that it ionizes. Complete discussions and tables can be found in Refs. [12, 15, 34].

For electrons, large energy transfers to atomic electrons (taken as free) are described by the Møller cross section. From Eq. (34.4), the maximum energy transfer in a single collision should be the entire kinetic energy, $W_{\max} = m_e c^2 (\gamma - 1)$, but because the particles are identical, the maximum is half this, $W_{\max}/2$. (The results are the same if the transferred energy is $\epsilon$ or if the transferred energy is $W_{\max} - \epsilon$. The stopping power is by convention calculated for the faster of the two emerging electrons.) The first moment of the Møller cross section [27] (divided by $dx$) is the stopping power:

$$
\left\langle -\frac{dE}{dx} \right\rangle = \frac{1}{2} K \frac{Z}{A} \frac{1}{\beta^2} \left[ \ln \frac{m_e c^2 \beta^2 \gamma^2 \{ m_e c^2 (\gamma - 1)/2 \}}{I^2} + (1 - \beta^2) - \frac{2\gamma - 1}{\gamma^2} \ln 2 + \frac{1}{8} \left( \frac{\gamma - 1}{\gamma} \right)^2 - \delta \right]
\quad (34.23)
$$

The logarithmic term can be compared with the logarithmic term in the Bethe equation (Eq. (34.2)) by substituting $W_{\max} = m_e c^2 (\gamma - 1)/2$. Electron-positron scattering is described by the fairly complicated Bhabha cross section [27]. There is no identical particle problem, so $W_{\max} = m_e c^2 (\gamma - 1)$. The first moment of the Bhabha equation yields

$$
\left\langle -\frac{dE}{dx} \right\rangle = \frac{1}{2} K \frac{Z}{A} \frac{1}{\beta^2} \left[ \ln \frac{m_e c^2 \beta^2 \gamma^2 \{ m_e c^2 (\gamma - 1) \}}{2 I^2} + 2 \ln 2 - \frac{\beta^2}{12} \left( 23 + \frac{14}{\gamma + 1} + \frac{10}{(\gamma + 1)^2} + \frac{4}{(\gamma + 1)^3} \right) - \delta \right] .
\quad (34.24)
$$

Following ICRU 37 [12], the density effect correction $\delta$ has been added to Uehling's equations [27] in both cases.

For heavy particles, shell corrections were developed assuming that the projectile is equivalent to a perturbing potential whose center moves with constant speed. This assumption has no sound theoretical basis for electrons. The authors of ICRU 37 [12] estimated the possible error in omitting it by assuming the correction was twice as great as for a proton of the same speed. At $T = 10$ keV, the error was estimated to be ≈2% for water, ≈9% for Cu, and ≈21% for Au.

As shown in Fig. 34.11, stopping powers for $e^-$, $e^+$, and heavy particles are not dramatically different. In silicon, the minimum value for electrons is 1.50 MeV cm²/g (at $\gamma = 3.3$); for positrons, 1.46 MeV cm²/g (at $\gamma = 3.7$), and for muons, 1.66 MeV cm²/g (at $\gamma = 3.58$).

> **Figure 34.11** *(PDF p. 19)*
> Original caption: "Fractional energy loss per radiation length in lead as a function of electron or positron energy. Electron (positron) scattering is considered as ionization when the energy loss per collision is below 0.255 MeV, and as Møller (Bhabha) scattering when it is above. Adapted from Fig. 3.2 from Messel and Crawford, Electron-Photon Shower Distribution Function Tables for Lead, Copper, and Air Absorbers, Pergamon Press, 1970. Messel and Crawford use X0(Pb) = 5.82 g/cm², but we have modified the figures to reflect the value given in the Table of Atomic and Nuclear Properties of Materials (X0(Pb) = 6.37 g/cm²)."
> Description: A log-log plot for lead (Z = 82) showing the fractional energy loss per radiation length, $-(1/E) dE/dx \cdot X_0$, versus electron or positron energy from 1 MeV to 1 TeV. Curves for ionization, bremsstrahlung, Møller scattering ($e^-$), Bhabha scattering ($e^+$), and positron annihilation are shown separately, along with totals for electrons and positrons. Bremsstrahlung dominates above ~10 MeV while ionization dominates at lower energies; the right vertical axis gives the equivalent value in cm²/g.

### 34.4.2 Radiation length

High-energy electrons predominantly lose energy in matter by bremsstrahlung, and high-energy photons by $e^+ e^-$ pair production. The characteristic amount of matter traversed for these related interactions is called the radiation length $X_0$, usually measured in g cm⁻². It is the mean distance over which a high-energy electron loses all but $1/e$ of its energy by bremsstrahlung. It is also the appropriate scale length for describing high-energy electromagnetic cascades. $X_0$ has been calculated and tabulated by Y.S. Tsai [42]:

$$
\frac{1}{X_0} = 4 \alpha r_e^2 \frac{N_A}{A} \left\{ Z^2 \left[ L_{\text{rad}} - f(Z) \right] + Z L'_{\text{rad}} \right\} .
\quad (34.25)
$$

For $A = 1$ g mol⁻¹, $4 \alpha r_e^2 N_A / A = (716.408 \text{ g cm}^{-2})^{-1}$. $L_{\text{rad}}$ and $L'_{\text{rad}}$ are given in Table 34.2. The function $f(Z)$ is an infinite sum, but for elements up to uranium can be represented to 4-place accuracy by

$$
f(Z) = a^2 \left[ (1 + a^2)^{-1} + 0.20206 - 0.0369 \, a^2 + 0.0083 \, a^4 - 0.002 \, a^6 \right] ,
\quad (34.26)
$$

where $a = \alpha Z$ [43].

The radiation length in a mixture or compound may be approximated by

$$
1/X_0 = \sum_j w_j / X_j ,
\quad (34.27)
$$

where $w_j$ and $X_j$ are the fraction by weight and the radiation length for the $j$th element.

**Table 34.2:** Tsai's $L_{\text{rad}}$ and $L'_{\text{rad}}$, for use in calculating the radiation length in an element using Eq. (34.25).

| Element | Z     | $L_{\text{rad}}$        | $L'_{\text{rad}}$       |
|---------|-------|-------------------------|-------------------------|
| H       | 1     | 5.31                    | 6.144                   |
| He      | 2     | 4.79                    | 5.621                   |
| Li      | 3     | 4.74                    | 5.805                   |
| Be      | 4     | 4.71                    | 5.924                   |
| Others  | > 4   | $\ln(184.15 \, Z^{-1/3})$ | $\ln(1194 \, Z^{-2/3})$ |

### 34.4.3 Bremsstrahlung energy loss by e±

At very high energies and except at the high-energy tip of the bremsstrahlung spectrum, the cross section can be approximated in the "complete screening case" as [42]

$$
d\sigma/dk = (1/k) 4 \alpha r_e^2 \left\{ \left( \tfrac{4}{3} - \tfrac{4}{3} y + y^2 \right) \left[ Z^2 (L_{\text{rad}} - f(Z)) + Z L'_{\text{rad}} \right] + \tfrac{1}{9} (1 - y)(Z^2 + Z) \right\} ,
\quad (34.28)
$$

where $y = k/E$ is the fraction of the electron's energy transferred to the radiated photon. At small $y$ (the "infrared limit") the term on the second line ranges from 1.7% (low $Z$) to 2.5% (high $Z$) of the total. If it is ignored and the first line simplified with the definition of $X_0$ given in Eq. (34.25), we have

$$
\frac{d\sigma}{dk} = \frac{A}{X_0 N_A k} \left( \tfrac{4}{3} - \tfrac{4}{3} y + y^2 \right) .
\quad (34.29)
$$

This cross section (times $k$) is shown by the top curve in Fig. 34.12.

> **Figure 34.12** *(PDF p. 20)*
> Original caption: "The normalized bremsstrahlung cross section $k \, d\sigma_{LPM}/dk$ in lead versus the fractional photon energy $y = k/E$. The vertical axis has units of photons per radiation length."
> Description: A family of curves on linear axes plotting $(X_0 N_A / A) \, y \, d\sigma_{LPM}/dy$ in lead against $y = k/E$ from 0 to 1, for incident electron energies of 10 GeV, 100 GeV, 1 TeV, 10 TeV, 100 TeV, 1 PeV, and 10 PeV. The 10 GeV curve is nearly flat (the high-energy non-LPM limit), while higher-energy curves show the LPM suppression at small $y$ and become progressively more depressed across most of the $y$ range as energy increases.

This formula is accurate except near $y = 1$, where screening may become incomplete, and near $y = 0$, where the infrared divergence is removed by the interference of bremsstrahlung amplitudes from nearby scattering centers (the LPM effect) [44, 45] and dielectric suppression [46, 47]. These and other suppression effects in bulk media are discussed in Sec. 34.4.6.

With decreasing energy ($E \lesssim 10$ GeV) the high-$y$ cross section drops and the curves become rounded as $y \to 1$. Curves of this familar shape can be seen in Rossi [2] (Figs. 2.11.2,3); see also the review by Koch & Motz [48].

Except at these extremes, and still in the complete-screening approximation, the number of photons with energies between $k_{\min}$ and $k_{\max}$ emitted by an electron travelling a distance $d \ll X_0$ is

$$
N_\gamma = \frac{d}{X_0} \left[ \frac{4}{3} \ln \left( \frac{k_{\max}}{k_{\min}} \right) - \frac{4(k_{\max} - k_{\min})}{3 E} + \frac{k_{\max}^2 - k_{\min}^2}{2 E^2} \right] .
\quad (34.30)
$$

### 34.4.4 Critical energy

An electron loses energy by bremsstrahlung at a rate nearly proportional to its energy, while the ionization loss rate varies only logarithmically with the electron energy. The *critical energy* $E_c$ is sometimes defined as the energy at which the two loss rates are equal [49]. Among alternate definitions is that of Rossi [2], who defines the critical energy as the energy at which the ionization loss per radiation length is equal to the electron energy. Equivalently, it is the same as the first definition with the approximation $|dE/dx|_{\text{brems}} \approx E/X_0$. This form has been found to describe transverse electromagnetic shower development more accurately (see below). These definitions are illustrated in the case of copper in Fig. 34.13.

> **Figure 34.13** *(PDF p. 21)*
> Original caption: "Two definitions of the critical energy $E_c$."
> Description: A log-log plot for copper ($X_0 = 12.86$ g cm⁻², $E_c = 19.63$ MeV) showing $dE/dx \times X_0$ in MeV against electron energy from 2 to 200 MeV. Curves for total energy loss, ionization, exact bremsstrahlung, and the Rossi approximation "Brems ≈ E" are drawn; the two definitions of $E_c$ correspond respectively to the crossing of bremsstrahlung with ionization and to the crossing of "ionization per $X_0$ = electron energy."

The accuracy of approximate forms for $E_c$ has been limited by the failure to distinguish between gases and solid or liquids, where there is a substantial difference in ionization at the relevant energy because of the density effect. We distinguish these two cases in Fig. 34.14. Fits were also made with functions of the form $a/(Z + b)^\alpha$, but $\alpha$ was found to be essentially unity. Since $E_c$ also depends on $A$, $I$, and other factors, such forms are at best approximate.

Values of $E_c$ for both electrons and positrons in more than 300 materials at pdg.lbl.gov/current/AtomicNuclearProperties.

> **Figure 34.14** *(PDF p. 22)*
> Original caption: "Electron critical energy for the chemical elements, using Rossi's definition [2]. The fits shown are for solids and liquids (solid line) and gases (dashed line). The rms deviation is 2.2% for the solids and 4.0% for the gases."
> Description: A log-log plot of the critical energy $E_c$ (MeV) versus atomic number $Z$ from 1 to 100, with data points for solids (crosses) and gases (open circles) for the chemical elements from H through beyond Sn. Two fitted curves are overlaid and labeled on the plot: $610 \text{ MeV}/(Z + 1.24)$ for solids and liquids, and $710 \text{ MeV}/(Z + 0.92)$ for gases.

### 34.4.5 Energy loss by photons

Contributions to the photon cross section in a light element (carbon) and a heavy element (lead) are shown in Fig. 34.15. At low energies it is seen that the photoelectric effect dominates, although Compton scattering, Rayleigh scattering, and photonuclear absorption also contribute. The photoelectric cross section is characterized by discontinuities (absorption edges) as thresholds for photoionization of various atomic levels are reached. Photon attenuation lengths for a variety of elements are shown in Fig. 34.16, and data for 30 eV < k < 100 GeV for all elements are available from the web pages given in the caption. Here k is the photon energy.

The increasing domination of pair production as the energy increases is shown in Fig. 34.17. Using approximations similar to those used to obtain Eq. (34.29), Tsai's formula for the differential cross section [42] reduces to

$$\frac{d\sigma}{dx} = \frac{A}{X_0 N_A}\left[1 - \tfrac{4}{3} x(1-x)\right] \quad (34.31)$$

in the complete-screening limit valid at high energies. Here x = E/k is the fractional energy transfer to the pair-produced electron (or positron), and k is the incident photon energy. The cross section is very closely related to that for bremsstrahlung, since the Feynman diagrams are variants of one another. The cross section is of necessity symmetric between x and 1 − x, as can be seen by the solid curve in Fig. 34.18. See the review by Motz, Olsen, & Koch for a more detailed treatment [54]. Eq. (34.31) may be integrated to find the high-energy limit for the total e+ e− pair-production cross section:

$$\sigma = \tfrac{7}{9}(A/X_0 N_A). \quad (34.32)$$

Equation Eq. (34.32) is accurate to within a few percent down to energies as low as 1 GeV, particularly for high-Z materials.

> **Figure 34.15** *(PDF p. 23)*
> Original caption: "Photon total cross sections as a function of energy in carbon and lead, showing the contributions of different processes [50]: σp.e. = Atomic photoelectric effect (electron ejection, photon absorption); σRayleigh = Rayleigh (coherent) scattering–atom neither ionized nor excited; σCompton = Incoherent scattering (Compton scattering off an electron); κnuc = Pair production, nuclear field; κe = Pair production, electron field; σg.d.r. = Photonuclear interactions, most notably the Giant Dipole Resonance [51]. In these interactions, the target nucleus is usually broken up. Original figures through the courtesy of John H. Hubbell (NIST)."
> Description: Two stacked log-log plots showing photon cross section in barns/atom versus photon energy from 10 eV to 100 GeV, for carbon (Z=6) on top and lead (Z=82) on bottom. Each panel decomposes the total cross section into photoelectric, Rayleigh, Compton, nuclear-field pair production, electron-field pair production, and (for lead) the giant dipole resonance contribution. Experimental total cross-section points are overlaid and track the summed curves across roughly nine decades in energy.

### 34.4.6 Bremsstrahlung and pair production at very high energies

At ultrahigh energies, Eqns. 34.28–34.32 will fail because of quantum mechanical interference between amplitudes from different scattering centers. Since the longitudinal momentum transfer to a given center is small (∝ k/E(E − k), in the case of bremsstrahlung), the interaction is spread over a comparatively long distance called the formation length (∝ E(E − k)/k) via the uncertainty principle. In alternate language, the formation length is the distance over which the highly relativistic electron and the photon "split apart." The interference is usually destructive. Calculations of the "Landau-Pomeranchuk-Migdal" (LPM) effect may be made semi-classically based on the average multiple scattering, or more rigorously using a quantum transport approach [44, 45].

In amorphous media, bremsstrahlung is suppressed if the photon energy k is less than E²/(E + ELPM) [45], where⁸

$$E_{LPM} = (m_e c^2)^2 \alpha \frac{X_0}{4\pi \hbar c \rho} = (7.7\,\text{TeV/cm}) \times \frac{X_0}{\rho}. \quad (34.33)$$

Since physical distances are involved, X0/ρ, in cm, appears. The energy-weighted bremsstrahlung spectrum for lead, k dσLPM/dk, is shown in Fig. 34.12. With appropriate scaling by X0/ρ, other materials behave similarly.

For photons, pair production is reduced for E(k − E) > k ELPM. The pair-production cross sections for different photon energies are shown in Fig. 34.18.

If k ≪ E, several additional mechanisms can also produce suppression. When the formation length is long, even weak factors can perturb the interaction. For example, the emitted photon can coherently forward scatter off of the electrons in the media. Because of this, for k < ωp E/me ∼ 10⁻⁴, bremsstrahlung is suppressed by a factor (kme/ωp E)² [47]. Magnetic fields can also suppress bremsstrahlung.

In crystalline media, the situation is more complicated, with coherent enhancement or suppression possible. The cross section depends on the electron and photon energies and the angles between the particle direction and the crystalline axes [56].

⁸ This definition differs from that of Ref. [55] by a factor of two. ELPM scales as the 4th power of the mass of the incident particle, so that ELPM = (1.4 × 10¹⁰ TeV/cm) × X0/ρ for a muon.

> **Figure 34.16** *(PDF p. 24)*
> Original caption: "The photon mass attenuation length (or mean free path) λ = 1/(µ/ρ) for various elemental absorbers as a function of photon energy. The mass attenuation coefficient is µ/ρ, where ρ is the density. The intensity I remaining after traversal of thickness t (in mass/unit area) is given by I = I0 exp(−t/λ). The accuracy is a few percent. For a chemical compound or mixture, 1/λeff ≈ Σelements wZ/λZ, where wZ is the proportion by weight of the element with atomic number Z. The processes responsible for attenuation are given in Fig. 34.11. Since coherent processes are included, not all these processes result in energy deposition. The data for 30 eV < E < 1 keV are from Ref. [52], those for 1 keV < E < 100 GeV from Ref. [53]."
> Description: Log-log plot of mass attenuation length λ in g/cm² versus photon energy from 10 eV up to 100 GeV for elemental absorbers H, C, Si, Fe, Sn, and Pb. Curves rise sharply across the keV range — with absorption edges visible for the higher-Z elements — and plateau at high energies once pair production saturates. Heavier elements show shorter attenuation lengths in the X-ray regime but converge with lighter elements at the highest energies displayed.

> **Figure 34.17** *(PDF p. 25)*
> Original caption: "Probability P that a photon interaction will result in conversion to an e+ e− pair. Except for a few-percent contribution from photonuclear absorption around 10 or 20 MeV, essentially all other interactions in this energy range result in Compton scattering off an atomic electron. For a photon attenuation length λ (Fig. 34.16), the probability that a given photon will produce an electron pair (without first Compton scattering) in thickness t of absorber is P[1 − exp(−t/λ)]."
> Description: Linear-log plot of pair-conversion probability versus photon energy from 1 MeV to roughly 1 GeV for H, C, H2O, Ar, Fe, Pb, and NaI. Higher-Z absorbers (Pb, NaI) reach probabilities near unity by tens of MeV, while lower-Z absorbers (notably H) approach unity only well above 100 MeV. The spread between curves illustrates how the relative weight of pair production versus Compton scattering depends on Z across this energy window.

### 34.4.7 Photonuclear and electronuclear interactions at still higher energies

At still higher photon and electron energies, where the bremsstrahlung and pair production cross-sections are heavily suppressed by the LPM effect, photonuclear and electronuclear interactions predominate over electromagnetic interactions.

At photon energies above about 10²⁰ eV, for example, photons usually interact hadronically. The exact cross-over energy depends on the model used for the photonuclear interactions. These processes are illustrated in Fig. 34.19. At still higher energies (≳ 10²³ eV), photonuclear interactions can become coherent, with the photon interaction spread over multiple nuclei. Essentially, the photon coherently converts to a ρ⁰, in a process that is somewhat similar to kaon regeneration [57].

Similar processes occur for electrons. As electron energies increase and the LPM effect suppresses bremsstrahlung, electronuclear interactions become more important. At energies above 10²¹ eV, these electronuclear interactions dominate electron energy loss [57].

> **Figure 34.18** *(PDF p. 26)*
> Original caption: "The normalized pair production cross section dσLPM/dx, versus fractional electron energy x = E/k."
> Description: Plot of (X0 NA/A) dσLPM/dx versus the fractional electron energy x = E/k from 0 to 1, with one curve per labeled photon energy from 1 TeV up to 1 EeV. At 1 TeV the distribution is essentially the symmetric Bethe-Heitler shape (high at the endpoints, dipping near x = 0.5), and as the photon energy rises through 10 TeV, 100 TeV, 1 PeV, 10 PeV, 100 PeV and 1 EeV the LPM suppression progressively flattens the central region while leaving narrow spikes at x → 0 and x → 1. The plot illustrates how the bulk of the pair-production phase space is depleted at ultra-high photon energies.

> **Figure 34.19** *(PDF p. 26)*
> Original caption: "Interaction length for a photon in ice as a function of photon energy for the Bethe-Heitler (BH), LPM (Mig) and photonuclear (γA) cross sections [57]. The Bethe-Heitler interaction length is 9X0/7, and X0 is 0.393 m in ice."
> Description: Log-log plot of the photon interaction length (in metres) versus log10 k (eV) from 10¹⁰ to 10²⁶ eV in ice, with separate curves for the unsuppressed Bethe-Heitler process, the LPM-suppressed (Migdal) bremsstrahlung/pair process, the photonuclear γA channel, and the combined Mig + γA total. The BH curve is a flat horizontal line at 9X0/7, the Mig curve rises steeply once LPM suppression turns on around 10¹⁵ eV, and the γA curve gradually decreases with energy so that the combined interaction length levels off near 10²¹ eV where photonuclear interactions take over from suppressed pair production.

## 34.5 Electromagnetic cascades

When a high-energy electron or photon is incident on a thick absorber, it initiates an electromagnetic cascade as pair production and bremsstrahlung generate more electrons and photons with lower energy. The longitudinal development is governed by the high-energy part of the cascade, and therefore scales as the radiation length in the material. Electron energies eventually fall below the critical energy, and then dissipate their energy by ionization and excitation rather than by the generation of more shower particles. In describing shower behavior, it is therefore convenient to introduce the scale variables

$$
t = x/X_0, \qquad y = E/E_c, \tag{34.34}
$$

so that distance is measured in units of radiation length and energy in units of critical energy.

> **Figure 34.20** *(PDF p. 27)*
> Original caption: "An EGS4 simulation of a 30 GeV electron-induced cascade in iron. The histogram shows fractional energy deposition per radiation length, and the curve is a gamma-function fit to the distribution. Circles indicate the number of electrons with total energy greater than 1.5 MeV crossing planes at $X_0/2$ intervals (scale on right) and the squares the number of photons with $E \geq 1.5$ MeV crossing the planes (scaled down to have same area as the electron distribution)."
> Description: A two-axis plot showing the longitudinal development of a 30 GeV electron shower in iron as a function of depth $t$ in radiation lengths from 0 to 20. The left axis gives the fractional energy deposition per radiation length $(1/E_0)\,dE/dt$ peaking near $t \approx 6$, while the right axis gives the number of electrons and photons (the latter scaled by $1/6.8$) crossing planes at half-radiation-length intervals. A gamma-function fit overlays the histogram of energy deposition.

Longitudinal profiles from an EGS4 [58] simulation of a 30 GeV electron-induced cascade in iron are shown in Fig. 34.20. The number of particles crossing a plane (very close to Rossi's $\Pi$ function [2]) is sensitive to the cutoff energy, here chosen as a total energy of 1.5 MeV for both electrons and photons. The electron number falls off more quickly than energy deposition. This is because, with increasing depth, a larger fraction of the cascade energy is carried by photons. Exactly what a calorimeter measures depends on the device, but it is not likely to be exactly any of the profiles shown. In gas counters it may be very close to the electron number, but in glass Cherenkov detectors and other devices with "thick" sensitive regions it is closer to the energy deposition (total track length). In such detectors the signal is proportional to the "detectable" track length $T_d$, which is in general less than the total track length $T$. Practical devices are sensitive to electrons with energy above some detection threshold $E_d$, and $T_d = T\,F(E_d/E_c)$. An analytic form for $F(E_d/E_c)$ obtained by Rossi [2] is given by Fabjan in Ref. [59]; see also Amaldi [60].

The mean longitudinal profile of the energy deposition in an electromagnetic cascade is reasonably well described by a gamma distribution [61]:

$$
\frac{dE}{dt} = E_0\, b\, \frac{(bt)^{a-1} e^{-bt}}{\Gamma(a)} \tag{34.35}
$$

The maximum $t_{\max}$ occurs at $(a-1)/b$. We have made fits to shower profiles in elements ranging from carbon to uranium, at energies from 1 GeV to 100 GeV. The energy deposition profiles are well described by Eq. (34.35) with

$$
t_{\max} = (a-1)/b = 1.0 \times (\ln y + C_j), \qquad j = e, \gamma, \tag{34.36}
$$

where $C_e = -0.5$ for electron-induced cascades and $C_\gamma = +0.5$ for photon-induced cascades. To use Eq. (34.35), one finds $(a-1)/b$ from Eq. (34.36) and Eq. (34.34), then finds $a$ either by assuming $b \approx 0.5$ or by finding a more accurate value from Fig. 34.21. The results are very similar for the electron number profiles, but there is some dependence on the atomic number of the medium. A similar form for the electron number maximum was obtained by Rossi in the context of his "Approximation B," [2] (see Fabjan's review in Ref. [59]), but with $C_e = -1.0$ and $C_\gamma = -0.5$; we regard this as superseded by the EGS4 result.

The "shower length" $X_s = X_0/b$ is less conveniently parameterized, since $b$ depends upon both $Z$ and incident energy, as shown in Fig. 34.21. As a corollary of this $Z$ dependence, the number of electrons crossing a plane near shower maximum is underestimated using Rossi's approximation for carbon and seriously overestimated for uranium. Essentially the same $b$ values are obtained for incident electrons and photons. For many purposes it is sufficient to take $b \approx 0.5$.

The length of showers initiated by ultra-high energy photons and electrons is somewhat greater than at lower energies since the first or first few interaction lengths are increased via the mechanisms discussed above.

The gamma function distribution is very flat near the origin, while the EGS4 cascade (or a real cascade) increases more rapidly. As a result Eq. (34.35) fails badly for about the first two radiation lengths; it was necessary to exclude this region in making fits.

Because fluctuations are important, Eq. (34.35) should be used only in applications where average behavior is adequate. Grindhammer et al. have developed fast simulation algorithms in which the variance and correlation of $a$ and $b$ are obtained by fitting Eq. (34.35) to individually simulated cascades, then generating profiles for cascades using $a$ and $b$ chosen from the correlated distributions [62].

The transverse development of electromagnetic showers in different materials scales fairly accurately with the *Molière radius* $R_M$, given by [63, 64]

$$
R_M = X_0\, E_s/E_c, \tag{34.37}
$$

where $E_s \approx 21$ MeV (Table 34.1), and the Rossi definition of $E_c$ is used.

In a material containing a weight fraction $w_j$ of the element with critical energy $E_{cj}$ and radiation length $X_j$, the Molière radius is given by

$$
\frac{1}{R_M} = \frac{1}{E_s} \sum \frac{w_j\, E_{cj}}{X_j}\,. \tag{34.38}
$$

Measurements of the lateral distribution in electromagnetic cascades are shown in Refs. [63, 64]. On the average, only 10% of the energy lies outside the cylinder with radius $R_M$. About 99% is contained inside of $3.5 R_M$, but at this radius and beyond composition effects become important and the scaling with $R_M$ fails. The distributions are characterized by a narrow core, and broaden as the shower develops. They are often represented as the sum of two Gaussians.

> **Figure 34.21** *(PDF p. 29)*
> Original caption: "Fitted values of the scale factor $b$ for energy deposition profiles obtained with EGS4 for a variety of elements for incident electrons with $1 \leq E_0 \leq 100$ GeV. Values obtained for incident photons are essentially the same."
> Description: A semi-logarithmic plot of the gamma-distribution scale factor $b$ versus $y = E/E_c$ from 10 to 10,000, with four curves for carbon, aluminum, iron, and uranium. Carbon sits highest near $b \approx 0.7$, aluminum near 0.6, iron near 0.5, and uranium lowest near 0.45. The curves illustrate the mild dependence of $b$ on atomic number and energy that motivates the $b \approx 0.5$ approximation.

At high enough energies, the LPM effect (Sec. 34.4.6) reduces the cross sections for bremsstrahlung and pair production, and hence can cause significant elongation of electromagnetic cascades [45].

## 34.6 Muon energy loss at high energy

At sufficiently high energies, radiative processes become more important than ionization for all charged particles. For muons and pions in materials such as iron, this "critical energy" occurs at several hundred GeV. (There is no simple scaling with particle mass, but for protons the "critical energy" is much, much higher.) Radiative effects dominate the energy loss of energetic muons found in cosmic rays or produced at the newest accelerators. These processes are characterized by small cross sections, hard spectra, large energy fluctuations, and the associated generation of electromagnetic and (in the case of photonuclear interactions) hadronic showers [65–73] As a consequence, at these energies the treatment of energy loss as a uniform and continuous process is for many purposes inadequate.

It is convenient to write the average rate of muon energy loss as [74]

$$\langle -dE/dx \rangle = a(E) + b(E)\, E. \tag{34.39}$$

Here $a(E)$ is the ionization energy loss given by Eq. (34.5), and $b(E)$ is the sum of $e^+e^-$ pair production, bremsstrahlung, and photonuclear contributions. To the approximation that these slowly-varying functions are constant, the mean range $x_0$ of a muon with initial energy $E_0$ is given by

$$x_0 \approx (1/b)\, \ln(1 + E_0/E_{\mu c}), \tag{34.40}$$

where $E_{\mu c} = a/b$.

Fig. 34.22 shows contributions to $b(E)$ for iron. Since $a(E) \approx 0.002$ GeV g$^{-1}$ cm$^2$, $b(E)E$ dominates the energy loss above several hundred GeV, where $b(E)$ is nearly constant. The rates of energy loss for muons in hydrogen, uranium, and iron are shown in Fig. 34.23 [7].

> **Figure 34.22** *(PDF p. 30)*
> Original caption: "Contributions to the fractional energy loss by muons in iron due to $e^+e^-$ pair production, bremsstrahlung, and photonuclear interactions, as obtained from Groom et al. [7] except for post-Born corrections to the cross section for direct pair production from atomic electrons."
> Description: Log-linear plot of the radiative loss coefficient $10^6\,b(E)$ in g$^{-1}$ cm$^2$ versus muon energy from 1 to $10^5$ GeV in iron. Four curves show the total $b$ together with its pair-production, bremsstrahlung, and photonuclear (nuclear) components. Pair production is the dominant contribution across most of the displayed range, bremsstrahlung is comparable but smaller, and the nuclear term remains small and nearly flat.

The "muon critical energy" $E_{\mu c}$ can be defined more exactly as the energy at which radiative and ionization losses are equal, and can be found by solving $E_{\mu c} = a(E_{\mu c})/b(E_{\mu c})$. This definition corresponds to the solid-line intersection in Fig. 34.13, and is different from the Rossi definition we used for electrons. It serves the same function: below $E_{\mu c}$ ionization losses dominate, and above $E_{\mu c}$ radiative effects dominate. The dependence of $E_{\mu c}$ on atomic number $Z$ is shown in Fig. 34.24.

> **Figure 34.23** *(PDF p. 31)*
> Original caption: "The average energy loss of a muon in hydrogen, iron, and uranium as a function of muon energy. Contributions to $dE/dx$ in iron from ionization and pair production, bremsstrahlung and photonuclear interactions are also shown."
> Description: Log-log plot of $dE/dx$ in MeV g$^{-1}$ cm$^2$ versus muon energy from 1 GeV to $10^5$ GeV. Total curves are shown for hydrogen gas, iron, and uranium, and for iron the ionization, total radiative, pair, bremsstrahlung, and photonuclear components are decomposed. Ionization is nearly flat with energy while the radiative components rise steeply, crossing the ionization curve near the muon critical energy and dominating at higher energies.

The radiative cross sections are expressed as functions of the fractional energy loss $\nu$. The bremsstrahlung cross section goes roughly as $1/\nu$ over most of the range, while for the pair production case the distribution goes as $\nu^{-3}$ to $\nu^{-2}$ [75]. "Hard" losses are therefore more probable in bremsstrahlung, and in fact energy losses due to pair production may very nearly be treated as continuous. The simulated momentum distribution of an incident 1 TeV/$c$ muon beam after it crosses 3 m of iron is shown in Fig. 34.25 [7]. The most probable loss is 8 GeV, or 3.4 MeV g$^{-1}$ cm$^2$. The full width at half maximum is 9 GeV/$c$, or 0.9%. The radiative tail is almost entirely due to bremsstrahlung, although most of the events in which more than 10% of the incident energy lost experienced relatively hard photonuclear interactions. The latter can exceed detector resolution [76], necessitating the reconstruction of lost energy. Tables in Ref. [7] list the stopping power as 9.82 MeV g$^{-1}$ cm$^2$ for a 1 TeV muon, so that the mean loss should be 23 GeV ($\approx$ 23 GeV/$c$), for a final momentum of 977 GeV/$c$, far below the peak. This agrees with the indicated mean calculated from the simulation. Electromagnetic and hadronic cascades in detector materials can obscure muon tracks in detector planes and reduce tracking efficiency [77].

> **Figure 34.24** *(PDF p. 32)*
> Original caption: "Muon critical energy for the chemical elements, defined as the energy at which radiative and ionization energy loss rates are equal [7]. The equality comes at a higher energy for gases than for solids or liquids with the same atomic number because of a smaller density effect reduction of the ionization losses. The fits shown in the figure exclude hydrogen. Alkali metals fall 3–4% above the fitted function, while most other solids are within 2% of the function. Among the gases the worst fit is for radon (2.7% high)."
> Description: Log-log scatter plot of muon critical energy $E_{\mu c}$ in GeV against atomic number $Z$ from 1 to about 100. Two data sets — gases (open circles) and solids (plus signs) — fall along separate fitted curves of the form $7980\,\text{GeV}/(Z+2.03)^{0.879}$ for gases and $5700\,\text{GeV}/(Z+1.47)^{0.838}$ for solids. The gas curve sits above the solid curve, illustrating the density-effect difference; both decrease smoothly with $Z$ from a few thousand GeV at hydrogen to about 100 GeV near $Z = 100$.

> **Figure 34.25** *(PDF p. 32)*
> Original caption: "The momentum distribution of 1 TeV/$c$ muons after traversing 3 m of iron as calculated by S.I. Striganov [7]."
> Description: Histogram of the differential probability $dN/dp$ in (GeV/$c$)$^{-1}$ versus final momentum $p$ from 950 to 1000 GeV/$c$ for an initial 1 TeV/$c$ muon beam. The distribution is sharply peaked near 991 GeV/$c$ with a narrow FWHM of 9 GeV/$c$ and a long tail extending to lower momenta from radiative losses. The median is 987 GeV/$c$ while the mean lies at 977 GeV/$c$, far below the peak, reflecting the strong asymmetry produced by hard bremsstrahlung events.

## 34.7 Cherenkov and transition radiation [3, 78, 79]

A charged particle radiates if its speed is greater than the local phase speed of light (Cherenkov radiation) or if it crosses suddenly from one medium to another with different optical properties (transition radiation). Neither process is important for energy loss, but both are used in high-energy and cosmic-ray physics detectors.

### 34.7.1 Optical Cherenkov radiation

The angle $\theta_c$ of Cherenkov radiation, relative to the particle's direction, for a particle with speed $\beta c$ in a medium with index of refraction $n$ is

$$
\begin{aligned}
\cos\theta_c &= (1/n\beta) \\
\text{or}\quad \tan\theta_c &= \sqrt{\beta^2 n^2 - 1} \\
&\approx \sqrt{2(1 - 1/n\beta)} \quad \text{for small } \theta_c,\ e.g.\ \text{in gases.}
\end{aligned}
\tag{34.41}
$$

The threshold speed $\beta_t$ is $1/n$, and $\gamma_t = 1/(1 - \beta_t^2)^{1/2}$. Therefore, $\beta_t \gamma_t = 1/(2\delta + \delta^2)^{1/2}$, where $\delta = n - 1$. Values of $\delta$ for various commonly used gases are given as a function of pressure and wavelength in Ref. [80]. See its Table 6.1 for values at atmospheric pressure. Data for other commonly used materials are given in Ref. [81].

> **Figure 34.26** *(PDF p. 33)*
> Original caption: "Cherenkov light emission and wavefront angles. In a dispersive medium, $\theta_c + \eta \neq 90^0$."
> Description: Schematic diagram showing a charged particle moving horizontally with velocity $v = \beta c$ along a baseline. Two dashed lines emerge from a point on the particle trajectory: one labeled $v = v_g$ at angle $\theta_c$ (the Cherenkov emission angle) and another labeled "Cherenkov wavefront" at angle $\eta$. The angle $\gamma_c$ is also indicated. The figure illustrates that in a dispersive medium the Cherenkov emission angle $\theta_c$ and the wavefront angle $\eta$ do not add to 90°.

Practical Cherenkov radiator materials are dispersive. Let $\omega$ be the photon's frequency, and let $k = 2\pi/\lambda$ be its wavenumber. The photons propage at the group speed $v_g = d\omega/dk = c/[n(\omega) + \omega(dn/d\omega)]$. In a non-dispersive medium, this simplies to $v_g = c/n$.

In his classical paper, Tamm [82] showed that for dispersive media the radiation is concentrated in a thin conical shell whose vertex is at the moving charge, and whose opening half-angle $\eta$ is

$$
\begin{aligned}
\cot\eta &= \left[\frac{d}{d\omega}(\omega \tan\theta_c)\right]_{\omega_0} \\
&= \left[\tan\theta_c + \beta^2 \omega\, n(\omega)\, \frac{dn}{d\omega} \cot\theta_c\right]_{\omega_0},
\end{aligned}
\tag{34.42}
$$

where $\omega_0$ is the central value of the small frequency range under consideration. (See Fig. 34.26.) This cone has a opening half-angle $\eta$, and, unless the medium is non-dispersive ($dn/d\omega = 0$), $\theta_c + \eta \neq 90^0$. The Cherenkov wavefront 'sideslips' along with the particle [83]. This effect has timing implications for ring imaging Cherenkov counters [84], but it is probably unimportant for most applications.

The number of photons produced per unit path length of a particle with charge $ze$ and per unit energy interval of the photons is

$$
\begin{aligned}
\frac{d^2 N}{dE\, dx} &= \frac{\alpha z^2}{\hbar c} \sin^2\theta_c = \frac{\alpha^2 z^2}{r_e m_e c^2}\left(1 - \frac{1}{\beta^2 n^2(E)}\right) \\
&\approx 370 \sin^2\theta_c(E)\ \text{eV}^{-1}\text{cm}^{-1} \quad (z = 1),
\end{aligned}
\tag{34.43}
$$

or, equivalently,

$$
\frac{d^2 N}{dx\, d\lambda} = \frac{2\pi \alpha z^2}{\lambda^2}\left(1 - \frac{1}{\beta^2 n^2(\lambda)}\right).
\tag{34.44}
$$

The index of refraction $n$ is a function of photon energy $E = \hbar\omega$, as is the sensitivity of the transducer used to detect the light. For practical use, Eq. (34.43) must be multiplied by the the transducer response function and integrated over the region for which $\beta\, n(\omega) > 1$. Further details are given in the discussion of Cherenkov detectors in the Particle Detectors section (Sec. 35.5 of this *Review*).

When two particles are close together (lateral separation $\lesssim$ 1 wavelength), the electromagnetic fields from the particles may add coherently, affecting the Cherenkov radiation. Because of their opposite charges, the radiation from an $e^+ e^-$ pair at close separation is suppressed compared to two independent leptons [85].

### 34.7.2 Coherent radio Cherenkov radiation

Coherent Cherenkov radiation is produced by many charged particles with a non-zero net charge moving through matter on an approximately common "wavefront"—for example, the electrons and positrons in a high-energy electromagnetic cascade. The signals can be visible for energies above $10^{16}$ eV; see Sec. 36.3.3 for more details. The phenomenon is called the Askaryan effect [86]. Near the end of a shower, when typical particle energies are below $E_c$ (but still relativistic), a charge imbalance develops. Photons can Compton-scatter atomic electrons, and positrons can annihilate with atomic electrons to contribute even more photons which can in turn Compton scatter. These processes result in a roughly 20% excess of electrons over positrons in a shower. The net negative charge leads to coherent radio Cherenkov emission. The radiation includes a component from the decelerating charges (as in bremsstrahlung). Because the emission is coherent, the electric field strength is proportional to the shower energy, and the signal power increases as its square. The electric field strength also increases linearly with frequency, up to a maximum frequency determined by the lateral spread of the shower. This cutoff occurs at about 1 GHz in ice, and scales inversely with the Moliere radius. At low frequencies, the radiation is roughly isotropic, but, as the frequency rises toward the cutoff frequency, the radiation becomes increasingly peaked around the Cherenkov angle. The radiation is linearly polarized in the plane containing the shower axis and the photon direction. A measurement of the signal polarization can be used to help determine the shower direction. The characteristics of this radiation have been nicely demonstrated in a series of experiments at SLAC [87]. A detailed discussion of the radiation can be found in Ref. [88].

### 34.7.3 Transition radiation

The energy radiated when a particle with charge $ze$ crosses the boundary between vacuum and a medium with plasma frequency $\omega_p$ is

$$
I = \alpha z^2 \gamma \hbar \omega_p / 3,
\tag{34.45}
$$

where

$$
\hbar\omega_p = \sqrt{4\pi N_e r_e^3\, m_e c^2 / \alpha} = \sqrt{\rho\ (\text{in g/cm}^3)\ \langle Z/A\rangle} \times 28.81\ \text{eV}.
\tag{34.46}
$$

For styrene and similar materials, $\hbar\omega_p \approx 20$ eV; for air it is 0.7 eV.

> **Figure 34.27** *(PDF p. 35)*
> Original caption: "X-ray photon energy spectra for a radiator consisting of 200 25 µm thick foils of Mylar with 1.5 mm spacing in air (solid lines) and for a single surface (dashed line). Curves are shown with and without absorption. Adapted from Ref. [89]."
> Description: Log-log plot of differential yield per interface $dS/d(\hbar\omega)$ in keV/keV versus x-ray energy $\hbar\omega$ in keV, spanning 1 to 1000 keV on the horizontal axis and $10^{-5}$ to nearly $10^{-2}$ on the vertical axis, for $\gamma = 2 \times 10^4$. A blue dashed curve shows the smooth single-interface spectrum, while two red solid curves show the 200-foil radiator response with and without absorption. The 200-foil curves exhibit interference oscillations at low energies and saturate (drop below) the single-interface curve at higher energies, with the absorption curve suppressed at low x-ray energies.

The number spectrum $dN_\gamma/d(\hbar\omega)$ diverges logarithmically at low energies and decreases rapidly for $\hbar\omega/\gamma\hbar\omega_p > 1$. About half the energy is emitted in the range $0.1 \leq \hbar\omega/\gamma\hbar\omega_p \leq 1$. Inevitable absorption in a practical detector removes the divergence. For a particle with $\gamma = 10^3$, the radiated photons are in the soft x-ray range 2 to 40 keV. The $\gamma$ dependence of the emitted energy thus comes from the hardening of the spectrum rather than from an increased quantum yield.

The number of photons with energy $\hbar\omega > \hbar\omega_0$ is given by the answer to problem 13.15 in Ref. [3],

$$
N_\gamma(\hbar\omega > \hbar\omega_0) = \frac{\alpha z^2}{\pi}\left[\left(\ln\frac{\gamma\hbar\omega_p}{\hbar\omega_0} - 1\right)^2 + \frac{\pi^2}{12}\right],
\tag{34.47}
$$

within corrections of order $(\hbar\omega_0/\gamma\hbar\omega_p)^2$. The number of photons above a fixed energy $\hbar\omega_0 \ll \gamma\hbar\omega_p$ thus grows as $(\ln\gamma)^2$, but the number above a fixed fraction of $\gamma\hbar\omega_p$ (as in the example above) is constant. For example, for $\hbar\omega > \gamma\hbar\omega_p/10$, $N_\gamma = 2.519\, \alpha z^2/\pi = 0.59\% \times z^2$.

The particle stays "in phase" with the x ray over a distance called the formation length, $d(\omega) = (2c/\omega)(1/\gamma^2 + \theta^2 + \omega_p^2/\omega^2)^{-1}$. Most of the radiation is produced in this distance. Here $\theta$ is the x-ray emission angle, characteristically $1/\gamma$. For $\theta = 1/\gamma$ the formation length has a maximum at $d(\gamma\omega_p/\sqrt{2}) = \gamma c/\sqrt{2}\, \omega_p$. In practical situations it is tens of µm.

Since the useful x-ray yield from a single interface is low, in practical detectors it is enhanced by using a stack of $N$ foil radiators—foils $L$ thick, where $L$ is typically several formation lengths—separated by gas-filled gaps. The amplitudes at successive interfaces interfere to cause oscillations about the single-interface spectrum. At increasing frequencies above the position of the last interference maximum ($L/d(w) = \pi/2$), the formation zones, which have opposite phase, overlap more and more and the spectrum saturates, $dI/d\omega$ approaching zero as $L/d(\omega) \to 0$. This is illustrated in Fig. 34.27 for a realistic detector configuration.

For regular spacing of the layers fairly complicated analytic solutions for the intensity have been obtained [89, 90]. Although one might expect the intensity of coherent radiation from the stack of foils to be proportional to $N^2$, the angular dependence of the formation length conspires to make the intensity $\propto N$.

## References

1. H. Bichsel, *Nucl. Instrum. Meth.* **A562**, 154 (2006).
2. B. Rossi, *High Energy Particles*, Prentice-Hall, Inc., Englewood Cliffs, NJ, 1952.
3. J.D. Jackson, *Classical Electrodynamics*, 3rd edition, (John Wiley and Sons, New York, 1998).
4. H.A. Bethe, *Zur Theorie des Durchgangs schneller Korpuskularstrahlen durch Materie,* H. Bethe, *Ann. Phys.* **5**, 325 (1930).
5. M. S. Livingston and H. A. Bethe, *Rev. Mod. Phys.* **9**, 245 (1937).
6. "Stopping Powers and Ranges for Protons and Alpha Particles," ICRU Report No. 49 (1993); Tables and graphs are available at physics.nist.gov/PhysRefData/Star/Text/PSTAR.html and physics.nist.gov/PhysRefData/Star/Text/ASTAR.html.
7. D.E. Groom, N.V. Mokhov, and S.I. Striganov, "Muon stopping-power and range tables: 10 MeV–100 TeV," *Atomic Data and Nuclear Data Tables* **78**, 183–356 (2001). Since submission of this paper it has become likely that post-Born corrections to the direct pair production cross section should be made. Code used to make Figs. 34.22–34.24 included these corrections [D.Yu. Ivanov et al., *Phys. Lett.* **B442**, 453 (1998)]. The effect is negligible except at high Z. (It is less than 1% for iron.); The introductory text of the paper can be found at pdg.lbl.gov/current/AtomicNuclearProperties/adndt.pdf Extensive printable and machine-readable tables for muons are given at pdg.lbl.gov/current/AtomicNuclearProperties/.
8. W. H. Barkas, W. Birnbaum and F. M. Smith, *Phys. Rev.* **101**, 778 (1956).
9. U. Fano, *Ann. Rev. Nucl. Part. Sci.* **13**, 1 (1963).
10. J. D. Jackson, *Phys. Rev.* **D59**, 017301 (1999).
11. J. Lindhard and A. H. Sørensen, *Phys. Rev.* **A53**, 2443 (1996).
12. "Stopping Powers for Electrons and Positrons," ICRU Report No. 37 (1984); Tables and graphs are available at physics.nist.gov/PhysRefData/Star/Text/ESTAR.html .
13. H. Bichsel, *Phys. Rev.* **A46**, 5761 (1992).
14. W.H. Barkas and M.J. Berger, *Tables of Energy Losses and Ranges of Heavy Charged Particles*, NASA-SP-3013 (1964).
15. S.M. Seltzer and M.J. Berger, *Int. J. of Applied Rad.* **33**, 1189 (1982).
16. physics.nist.gov/PhysRefData/XrayMassCoef/tab1.html.
17. R. M. Sternheimer, *Phys. Rev.* **88**, 851 (1952).
18. R. M. Sternheimer, M. J. Berger and S. M. Seltzer, *Atom. Data Nucl. Data Tabl.* **30**, 261 (1984); Minor errors are corrected in Ref. 5. Chemical composition for the tabulated materials is given in Ref. 10.
19. R. M. Sternheimer and R. F. Peierls, *Phys. Rev.* **B3**, 3681 (1971).
20. N. F. Mott, *Proceedings of the Cambridge Philosophical Society* **27**, 553 (1931).
21. H. Bichsel, *Phys. Rev.* **A65**, 5, 052709 (2002).
22. S. P. Møller et al., *Phys. Rev.* **A56**, 4, 2930 (1997).
23. J. C. Ashley, R. H. Ritchie and W. Brandt, *Phys. Rev. B* **5**, 2393 (1972).
24. H.H. Andersen and J.F. Ziegler, *Hydrogen: Stopping Powers and Ranges in All Elements*. Vol. 3 of *The Stopping and Ranges of Ions in Matter* (Pergamon Press 1977).
25. J. Lindhard, *Kgl. Danske Videnskab. Selskab, Mat.-Fys. Medd.* **28**, No. 8 (1954); J. Lindhard, M. Scharff, and H.E. Schiøtt, *Kgl. Danske Videnskab. Selskab, Mat.-Fys. Medd.* **33**, No. 14 (1963).
26. J.F. Ziegler, J.F. Biersac, and U. Littmark, *The Stopping and Range of Ions in Solids*, Pergamon Press 1985.
27. E.A. Uehling, *Ann. Rev. Nucl. Sci.* **4**, 315 (1954) (For heavy particles with unit charge, but e± cross sections and stopping powers are also given).
28. N.F. Mott and H.S.W. Massey, *The Theory of Atomic Collisions*, Oxford Press, London, 1965.
29. P. V. Vavilov, *Sov. Phys. JETP* **5**, 749 (1957), [*Zh. Eksp. Teor. Fiz.* **32**, 920 (1957)].
30. L.D. Landau, *J. Exp. Phys. (USSR)* **8**, 201 (1944).
31. H. Bichsel, *Rev. Mod. Phys.* **60**, 663 (1988).
32. R. Talman, *Nucl. Instrum. Meth.* **159**, 189 (1979).
33. H. Bichsel, Ch. 87 in the *Atomic, Molecular and Optical Physics Handbook*, G.W.F. Drake, editor (Am. Inst. Phys. Press, Woodbury NY, 1996).
34. S.M. Seltzer and M.J. Berger, *Int. J. of Applied Rad.* **35**, 665 (1984). This paper corrects and extends the results of Ref. [15].
35. H. A. Bethe, *Phys. Rev.* **89**, 1256 (1953).
36. W. T. Scott, *Rev. Mod. Phys.* **35**, 231 (1963).
37. J. W. Motz, H. Olsen and H. W. Koch, *Rev. Mod. Phys.* **36**, 881 (1964).
38. H. Bichsel, *Phys. Rev.* **112**, 182 (1958).
39. G. Shen et al., *Phys. Rev.* **D20**, 1584 (1979).
40. G. R. Lynch and O. I. Dahl, *Nucl. Instrum. Meth.* **B58**, 6 (1991).
41. M. Wong et al., *Med. Phys.* **17**, 163 (1990).
42. Y.-S. Tsai, *Rev. Mod. Phys.* **46**, 815 (1974), [Erratum: *Rev. Mod. Phys.* **49**, 521 (1977)].
43. H. Davies, H. A. Bethe and L. C. Maximon, *Phys. Rev.* **93**, 788 (1954).
44. L. D. Landau and I. Pomeranchuk, *Dokl. Akad. Nauk Ser. Fiz.* **92**, 535 (1953); **92**, 735 (1953). These papers are available in English in L. Landau, *The Collected Papers of L.D. Landau*, Pergamon Press, 1965; A. B. Migdal, *Phys. Rev.* **103**, 1811 (1956).
45. S. Klein, *Rev. Mod. Phys.* **71**, 1501 (1999).
46. M.L. Ter-Mikaelian, *SSSR* **94**, 1033 (1954); M.L. Ter-Mikaelian, *High Energy Electromagnetic Processes in Condensed Media* (John Wiley and Sons, New York, 1972).
47. P. L. Anthony et al., *Phys. Rev. Lett.* **76**, 3550 (1996).
48. H. W. Koch and J. W. Motz, *Rev. Mod. Phys.* **31**, 920 (1959).
49. M.J. Berger and S.M. Seltzer, "Tables of Energy Losses and Ranges of Electrons and Positrons," National Aeronautics and Space Administration Report NASA-SP-3012 (Washington DC 1964).
50. Curves for these and other elements, compounds, and mixtures may be obtained from nist.gov/pml/xcom-photon-cross-sections-database. The photon total cross section is approximately flat for at least two decades beyond the energy range shown.
51. B. L. Berman and S. C. Fultz, *Rev. Mod. Phys.* **47**, 713 (1975).
52. www.cxro.lbl.gov/optical_constants/pert_form.html.
53. physics.nist.gov/PhysRefData/XrayMassCoef/tab3.html.
54. J. W. Motz, H. A. Olsen and H. W. Koch, *Rev. Mod. Phys.* **41**, 581 (1969).
55. P. L. Anthony et al., *Phys. Rev. Lett.* **75**, 1949 (1995).
56. U. I. Uggerhøj, *Rev. Mod. Phys.* **77**, 1131 (2005).
57. L. Gerhardt and S. R. Klein, *Phys. Rev.* **D82**, 074017 (2010).
58. W.R. Nelson, H. Hirayama, and D.W.O. Rogers, "The EGS4 Code System," SLAC-265, Stanford Linear Accelerator Center (Dec. 1985).
59. *Experimental Techniques in High Energy Physics*, ed. T. Ferbel (Addison-Wesley, Menlo Park CA 1987).
60. U. Amaldi, *Phys. Scripta* **23**, 409 (1981).
61. E. Longo and I. Sestili, *Nucl. Instrum. Meth.* **128**, 283 (1975), [Erratum: *Nucl. Instrum. Meth.* **135**, 587 (1976)].
62. G. Grindhammer et al., in *Proceedings of the 1988 Summer Study on High Energy Physics in the 1990's, Snowmass, CO, June 27 – July 15, 1990*, edited by F.J. Gilman and S. Jensen, (World Scientific, Teaneck, NJ, 1989) p. 151.
63. W. R. Nelson et al., *Phys. Rev.* **149**, 201 (1966).
64. G. Bathow et al., *Nucl. Phys.* **B20**, 592 (1970).
65. H. Bethe and W. Heitler, *Proc. Roy. Soc. Lond.* **A146**, 83 (1934); H.A. Bethe, *Proc. Cambridge Phil. Soc.* **30**, 542 (1934).
66. A.A. Petrukhin and V.V. Shestakov, *Can. J. Phys.* **46**, S377 (1968).
67. V.M. Galitskii and S.R. Kel'ner, *Sov. Phys. JETP* **25**, 948 (1967).
68. S.R. Kel'ner and Yu.D. Kotov, *Sov. J. Nucl. Phys.* **7**, 237 (1968).
69. R.P. Kokoulin and A.A. Petrukhin, in *Proceedings of the International Conference on Cosmic Rays, Hobart, Australia, August 16–25, 1971*, Vol. 4, p. 2436 .
70. A. I. Nikishov, *Sov. J. Nucl. Phys.* **27**, 677 (1978), [*Yad. Fiz.* **27**, 1281 (1978)].
71. Yu. M. Andreev, L. B. Bezrukov and E. V. Bugaev, *Phys. Atom. Nucl.* **57**, 2066 (1994), [*Yad. Fiz.* **57**, 2146 (1994)].
72. L. B. Bezrukov and E. V. Bugaev, *Yad. Fiz.* **33**, 1195 (1981), [*Sov. J. Nucl. Phys.* **33**, 635 (1981)].
73. N.V. Mokhov and C.C. James, *The MARS Code System User's Guide*, Fermilab-FN-1058-APC (2018), mars.fnal.gov/; N. Mokhov et al., *Prog. Nucl. Sci. Tech.* **4**, 496 (2014).
74. P. H. Barrett et al., *Rev. Mod. Phys.* **24**, 3, 133 (1952).
75. A. Van Ginneken, *Nucl. Instrum. Meth.* **A251**, 21 (1986).
76. U. Becker et al., *Nucl. Instrum. Meth.* **A253**, 15 (1986).
77. J.J. Eastman and S.C. Loken, in *Proceedings of the Workshop on Experiments, Detectors, and Experimental Areas for the Supercollider, Berkeley, CA, July 7–17, 1987*, edited by R. Donaldson and M.G.D. Gilchriese (World Scientific, Singapore, 1988), p. 542.
78. *Methods of Experimental Physics*, L.C.L. Yuan and C.-S. Wu, editors, Academic Press, 1961, Vol. 5A, p. 163.
79. W.W.M. Allison and P.R.S. Wright, "The Physics of Charged Particle Identification: dE/dx, Cherenkov Radiation, and Transition Radiation," p. 371 in *Experimental Techniques in High Energy Physics*, T. Ferbel, editor, (Addison-Wesley 1987).
80. E.R. Hayes, R.A. Schluter, and A. Tamosaitis, "Index and Dispersion of Some Cherenkov Counter Gases," ANL-6916 (1964).
81. T. Ypsilantis, in "Proceedings of the Symposium on Particle Identification at High Luminosity Hadron Colliders, Apr 5-7, 1989 Batavia, Ill.", 0661–676 (1989).
82. I. Tamm, *J. Phys. U.S.S.R.*, **1**, 439 (1939).
83. H. Motz and L.I. Schiff, *Am. J. Phys.* **21**, 258 (1953).
84. B. N. Ratcliff, *Nucl. Instrum. Meth.* **A502**, 211 (2003).
85. S. K. Mandal, S. R. Klein and J. D. Jackson, *Phys. Rev.* **D72**, 093003 (2005).
86. G. A. Askar'yan, *Sov. Phys. JETP* **14**, 2, 441 (1962), [*Zh. Eksp. Teor. Fiz.* **41**, 616 (1961)].
87. P. W. Gorham et al., *Phys. Rev.* **D72**, 023002 (2005).
88. E. Zas, F. Halzen and T. Stanev, *Phys. Rev.* **D45**, 362 (1992).
89. M. L. Cherry et al., *Phys. Rev.* **D10**, 3594 (1974); M. L. Cherry, *Phys. Rev.* **D17**, 2245 (1978).
90. B. Dolgoshein, *Nucl. Instrum. Meth.* **A326**, 434 (1993).
