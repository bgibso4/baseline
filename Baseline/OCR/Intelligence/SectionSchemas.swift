import FoundationModels

/// The answer shapes the on-device model fills in, one per question.
///
/// Small on purpose: the model reads a handful of numbers from one crop far
/// more reliably than many. Every value is optional so "cannot read it" has
/// somewhere to go, though in practice the model still guesses —
/// `ReadoutValidator` is what catches that.
enum SectionSchemas {

    @Generable
    struct BodyCompositionValues {
        @Guide(description: "Intracellular Water, in lbs")
        var intracellularWater: Double?
        @Guide(description: "Extracellular Water, in lbs")
        var extracellularWater: Double?
        @Guide(description: "Dry Lean Mass, in lbs")
        var dryLeanMass: Double?
        @Guide(description: "Body Fat Mass, in lbs")
        var bodyFatMass: Double?
    }

    @Generable
    struct BodyCompositionTotals {
        @Guide(description: "Total Body Water, in lbs: the leftmost of the three totals")
        var totalBodyWater: Double?
        @Guide(description: "Lean Body Mass, in lbs: the middle total")
        var leanBodyMass: Double?
        @Guide(description: "Weight, in lbs: the rightmost total")
        var weight: Double?
    }

    @Generable
    struct MuscleFat {
        @Guide(description: "Weight: the number printed at the end of the Weight bar")
        var weight: Double?
        @Guide(description: "SMM (Skeletal Muscle Mass): the number printed at the end of the SMM bar")
        var skeletalMuscleMass: Double?
        @Guide(description: "Body Fat Mass: the number printed at the end of the Body Fat Mass bar")
        var bodyFatMass: Double?
    }

    @Generable
    struct Obesity {
        @Guide(description: "BMI: the number printed at the end of the BMI bar")
        var bmi: Double?
        @Guide(description: "PBF (Percent Body Fat): the number printed at the end of the PBF bar")
        var percentBodyFat: Double?
    }

    @Generable
    struct SegmentalLean {
        @Guide(description: """
            Every result number, top to bottom: two per body part, the lbs value then the % value. \
            Results have a decimal point (11.49, 138.0). Skip the whole-number axis ticks (55, 70, 130, 160).
            """)
        var numbers: [Double]
    }

    @Generable
    struct EcwTbw {
        @Guide(description: "ECW/TBW ratio: the number printed at the end of the bar, e.g. 0.369")
        var ratio: Double?
    }

    @Generable
    struct SegmentalFatPounds {
        @Guide(description: "The five numbers inside the parentheses, top to bottom, e.g. 0.2 from '( 0.2lbs)'")
        var numbers: [Double]
    }

    @Generable
    struct SegmentalFatPercents {
        @Guide(description: "The five percentages at the end of each row, top to bottom, e.g. 14.4 from '14.4%'")
        var numbers: [Double]
    }

    @Generable
    struct BasalMetabolicRate {
        @Guide(description: "The whole number printed before 'kcal'")
        var kcal: Int?
    }

    @Generable
    struct VisceralFat {
        @Guide(description: "The number printed after the word 'Level'")
        var level: Int?
    }

    @Generable
    struct SkeletalMuscleIndex {
        @Guide(description: "SMI in kg/m2")
        var smi: Double?
    }

    @Generable
    struct Header {
        @Guide(description: "Test date month. The date is printed month first: MM.DD.YYYY", .range(1...12))
        var month: Int?
        @Guide(description: "Test date day of month, the second number of MM.DD.YYYY", .range(1...31))
        var day: Int?
        @Guide(description: "Test date four-digit year")
        var year: Int?
    }
}
