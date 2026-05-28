local GameplayConfig = {
	Roles = {
		Tagger = "Tagger",
		Survivor = "Survivor",
	},
	Tag = {
		MaxDistance = 5,
		NoTagBackTime = 3,
	},
	Invisibility = {
		Duration = 3,
		Cooldown = 20,
	},
	Shove = {
		MaxDistance = 6,
		Cooldown = 2,
		RagdollDuration = 2,
		Distance = 10,
		TravelTime = 0.2,
	},
	Movement = {
		DefaultWalkSpeed = 16,
		MaxSprintDuration = 3,
		NormalRecoveryDuration = 5,
		ExhaustedRecoveryDuration = 10,
		SprintSpeedMultiplier = 1.5,
		CrouchSpeedMultiplier = 0.55,
		JumpReductionMultiplier = 0.9,
		SlideSpeedMultiplier = 2.1,
		SlideBurstSpeedMultiplier = 2.6,
		SlideDuration = 1.5,
		SlideBurstDuration = 0.18,
		SlideSprintEnergyPenalty = 0.5,
	},
	TaskMinigame = {
		TotalSegments = 3,
		SuccessStep = 1,
		FailureStep = 1,
		GreenWidthMax = 0.24,
		GreenWidthMin = 0.12,
		MarkerWidthScale = 0.08,
		SidePaddingScale = 0.08,
		SwingSpeed = 0.9,
		Spam = {
			TotalStages = 3,
			GoalStartScale = 0.88,
			GoalWidthScale = 0.12,
			FillPerTap = 0.08,
			BaseDecayPerSecond = 0.12,
			StageDecayIncrease = 0.12,
		},
		Puzzle = {
			TotalStages = 3,
			RequiredCoverageByStage = { 0.9, 0.95, 0.98 },
			Stages = {
				-- Stage 1: 6×6, 7 crossing pairs – endpoints span all four quadrants
				{
					Size = 6,
					Pairs = {
						{ Id = 1, Color = "#FF6B6B", Endpoints = { { 1, 1 }, { 6, 6 } } },
						{ Id = 2, Color = "#4D96FF", Endpoints = { { 1, 6 }, { 6, 1 } } },
						{ Id = 3, Color = "#6BCB77", Endpoints = { { 1, 3 }, { 6, 4 } } },
						{ Id = 4, Color = "#FFD93D", Endpoints = { { 2, 1 }, { 5, 6 } } },
						{ Id = 5, Color = "#B980F0", Endpoints = { { 2, 6 }, { 5, 1 } } },
						{ Id = 6, Color = "#52D1DC", Endpoints = { { 3, 2 }, { 4, 5 } } },
						{ Id = 7, Color = "#FF9F1C", Endpoints = { { 3, 5 }, { 4, 2 } } },
					},
				},
				-- Stage 2: 8×8, 10 interleaved pairs
				{
					Size = 8,
					Pairs = {
						{ Id = 1,  Color = "#FF6B6B", Endpoints = { { 1, 1 }, { 8, 8 } } },
						{ Id = 2,  Color = "#4D96FF", Endpoints = { { 1, 8 }, { 8, 1 } } },
						{ Id = 3,  Color = "#6BCB77", Endpoints = { { 1, 4 }, { 8, 5 } } },
						{ Id = 4,  Color = "#FFD93D", Endpoints = { { 2, 1 }, { 7, 8 } } },
						{ Id = 5,  Color = "#B980F0", Endpoints = { { 2, 8 }, { 7, 1 } } },
						{ Id = 6,  Color = "#52D1DC", Endpoints = { { 1, 6 }, { 6, 1 } } },
						{ Id = 7,  Color = "#FF9F1C", Endpoints = { { 3, 2 }, { 6, 7 } } },
						{ Id = 8,  Color = "#FF85A1", Endpoints = { { 3, 7 }, { 6, 2 } } },
						{ Id = 9,  Color = "#F1F1F1", Endpoints = { { 4, 3 }, { 5, 6 } } },
						{ Id = 10, Color = "#FFBE0B", Endpoints = { { 4, 6 }, { 5, 3 } } },
					},
				},
				-- Stage 3: 10×10, 13 pairs – dense crossing layout, 98 % coverage needed
				{
					Size = 10,
					Pairs = {
						{ Id = 1,  Color = "#FF6B6B", Endpoints = { { 1, 1  }, { 10, 10 } } },
						{ Id = 2,  Color = "#4D96FF", Endpoints = { { 1, 10 }, { 10, 1  } } },
						{ Id = 3,  Color = "#6BCB77", Endpoints = { { 1, 5  }, { 10, 6  } } },
						{ Id = 4,  Color = "#FFD93D", Endpoints = { { 2, 1  }, { 9,  10 } } },
						{ Id = 5,  Color = "#B980F0", Endpoints = { { 2, 10 }, { 9,  1  } } },
						{ Id = 6,  Color = "#52D1DC", Endpoints = { { 1, 3  }, { 7,  10 } } },
						{ Id = 7,  Color = "#FF9F1C", Endpoints = { { 1, 8  }, { 7,  1  } } },
						{ Id = 8,  Color = "#FF85A1", Endpoints = { { 3, 2  }, { 8,  9  } } },
						{ Id = 9,  Color = "#F1F1F1", Endpoints = { { 3, 9  }, { 8,  2  } } },
						{ Id = 10, Color = "#A8E6CF", Endpoints = { { 4, 4  }, { 7,  7  } } },
						{ Id = 11, Color = "#FFBE0B", Endpoints = { { 4, 7  }, { 7,  4  } } },
						{ Id = 12, Color = "#9B5DE5", Endpoints = { { 5, 2  }, { 6,  9  } } },
						{ Id = 13, Color = "#F15BB5", Endpoints = { { 5, 9  }, { 6,  2  } } },
					},
				},
			},
		},
		Code = {
			TotalStages = 3,
			Letters = { "U", "H", "J", "K" },
			Stages = {
				{
					Lines = {
						{ Html = '<override code="acid-balance">', SequenceLength = 5 },
					},
				},
				{
					Lines = {
						{ Html = '<override code="sensor-lattice">', SequenceLength = 5 },
						{ Html = '<commit checksum="ion-grid" />', SequenceLength = 5 },
					},
				},
				{
					Lines = {
						{ Html = '<override code="cryo-thaw">', SequenceLength = 5 },
						{ Html = '<inject channel="aux-pump">', SequenceLength = 5 },
						{ Html = '<seal status="manual" />', SequenceLength = 5 },
					},
				},
			},
		},
	},
}

return GameplayConfig