// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/flow/layers/transform_layer.h"

#include "flutter/flow/testing/diff_context_test.h"
#include "flutter/flow/testing/layer_test.h"
#include "flutter/flow/testing/mock_layer.h"
#include "flutter/fml/macros.h"

namespace flutter {
namespace testing {

using TransformLayerTest = LayerTest;

// ASSERT_TRUE(result.has_value()) should be enough to prevent the test
// code that follows it to run, but clang-tidy doesn't seem to recognize
// that macro expansion as protective. This macro is more proactive
// about ending execution at the place where the statement lives.
#define ENFORCE_TRUE(condition) \
  do {                          \
    if (!(condition)) {         \
      ASSERT_TRUE(condition);   \
      return;                   \
    }                           \
  } while (0)

#ifndef NDEBUG
TEST_F(TransformLayerTest, PaintingEmptyLayerDies) {
  auto layer = std::make_shared<TransformLayer>(DlTransform());  // identity

  layer->Preroll(preroll_context());
  EXPECT_EQ(layer->paint_bounds(), DlFRect());
  EXPECT_EQ(layer->child_paint_bounds(), DlFRect());
  EXPECT_FALSE(layer->needs_painting(paint_context()));

  EXPECT_DEATH_IF_SUPPORTED(layer->Paint(paint_context()),
                            "needs_painting\\(context\\)");
}

TEST_F(TransformLayerTest, PaintBeforePrerollDies) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  auto mock_layer = std::make_shared<MockLayer>(child_path, DlPaint());
  auto layer = std::make_shared<TransformLayer>(DlTransform());  // identity
  layer->Add(mock_layer);

  EXPECT_DEATH_IF_SUPPORTED(layer->Paint(paint_context()),
                            "needs_painting\\(context\\)");
}
#endif

TEST_F(TransformLayerTest, Identity) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  DlFRect cull_rect = DlFRect::MakeXYWH(2.0f, 2.0f, 14.0f, 14.0f);
  auto mock_layer = std::make_shared<MockLayer>(child_path, DlPaint());
  auto layer = std::make_shared<TransformLayer>(DlTransform());  // identity
  layer->Add(mock_layer);

  preroll_context()->state_stack.set_preroll_delegate(cull_rect);
  layer->Preroll(preroll_context());
  EXPECT_EQ(mock_layer->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer->paint_bounds(), mock_layer->paint_bounds());
  EXPECT_EQ(layer->child_paint_bounds(), mock_layer->paint_bounds());
  EXPECT_TRUE(mock_layer->needs_painting(paint_context()));
  EXPECT_TRUE(layer->needs_painting(paint_context()));
  EXPECT_EQ(mock_layer->parent_matrix(), DlTransform());  // identity
  EXPECT_EQ(mock_layer->parent_cull_rect(), cull_rect);
  EXPECT_EQ(mock_layer->parent_mutators().stack_count(), 0u);
  EXPECT_EQ(mock_layer->parent_mutators(), MutatorsStack());

  layer->Paint(display_list_paint_context());
  DisplayListBuilder expected_builder;
  /* (Transform)layer::Paint */ {
    expected_builder.Save();
    {
      expected_builder.Transform(DlTransform());
      /* mock_layer::Paint */ {
        expected_builder.DrawPath(child_path, DlPaint());
      }
    }
    expected_builder.Restore();
  }
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

TEST_F(TransformLayerTest, Simple) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  DlTransform initial_transform = DlTransform::MakeTranslate(-0.5f, -0.5f);
  DlFRect local_cull_rect = DlFRect::MakeXYWH(2.0f, 2.0f, 14.0f, 14.0f);
  DlFRect device_cull_rect = initial_transform.TransformRect(local_cull_rect);
  DlTransform layer_transform = DlTransform::MakeTranslate(2.5f, 2.5f);
  auto inverse_layer_transform = layer_transform.Inverse();
  ENFORCE_TRUE(inverse_layer_transform.has_value());

  auto mock_layer = std::make_shared<MockLayer>(child_path, DlPaint());
  auto layer = std::make_shared<TransformLayer>(layer_transform);
  layer->Add(mock_layer);

  preroll_context()->state_stack.set_preroll_delegate(device_cull_rect,
                                                      initial_transform);
  layer->Preroll(preroll_context());
  EXPECT_EQ(mock_layer->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer->paint_bounds(),
            layer_transform.TransformRect(mock_layer->paint_bounds()));
  EXPECT_EQ(layer->child_paint_bounds(), mock_layer->paint_bounds());
  EXPECT_TRUE(mock_layer->needs_painting(paint_context()));
  EXPECT_TRUE(layer->needs_painting(paint_context()));
  EXPECT_EQ(mock_layer->parent_matrix(),
            DlTransform::MakeConcat(initial_transform, layer_transform));
  EXPECT_EQ(mock_layer->parent_cull_rect(),
            inverse_layer_transform->TransformRect(local_cull_rect));
  EXPECT_EQ(mock_layer->parent_mutators(),
            std::vector({Mutator(layer_transform)}));

  layer->Paint(display_list_paint_context());
  DisplayListBuilder expected_builder;
  /* (Transform)layer::Paint */ {
    expected_builder.Save();
    {
      expected_builder.Transform(layer_transform);
      /* mock_layer::Paint */ {
        expected_builder.DrawPath(child_path, DlPaint());
      }
    }
    expected_builder.Restore();
  }
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

TEST_F(TransformLayerTest, Complex) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  DlTransform initial_transform = DlTransform::MakeTranslate(-0.5f, -0.5f);
  DlFRect local_cull_rect = DlFRect::MakeXYWH(2.0f, 2.0f, 14.0f, 14.0f);
  DlFRect device_cull_rect = initial_transform.TransformRect(local_cull_rect);
  DlTransform layer_transform = DlTransform();
  layer_transform.TranslateInner(2.5f, 2.5f);
  // 20 degrees around the X axis
  layer_transform.ConcatInner(
      DlTransform::MakeRotate(kDlAxis_X, DlRadians(M_PI / 9.0f)));
  // 10 degrees around the Y axis
  layer_transform.ConcatInner(
      DlTransform::MakeRotate(kDlAxis_Y, DlRadians(M_PI / 18.0f)));
  auto inverse_layer_transform = layer_transform.Inverse();
  ENFORCE_TRUE(inverse_layer_transform.has_value());

  auto mock_layer = std::make_shared<MockLayer>(child_path, DlPaint());
  auto layer = std::make_shared<TransformLayer>(layer_transform);
  layer->Add(mock_layer);

  preroll_context()->state_stack.set_preroll_delegate(device_cull_rect,
                                                      initial_transform);
  layer->Preroll(preroll_context());
  EXPECT_EQ(mock_layer->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer->paint_bounds(),
            layer_transform.TransformRect(mock_layer->paint_bounds()));
  EXPECT_EQ(layer->child_paint_bounds(), mock_layer->paint_bounds());
  EXPECT_TRUE(mock_layer->needs_painting(paint_context()));
  EXPECT_TRUE(layer->needs_painting(paint_context()));
  EXPECT_EQ(mock_layer->parent_matrix(),
            DlTransform::MakeConcat(initial_transform, layer_transform));
  EXPECT_EQ(mock_layer->parent_cull_rect(),
            inverse_layer_transform->TransformRect(local_cull_rect));
  EXPECT_EQ(mock_layer->parent_mutators(),
            std::vector({Mutator(layer_transform)}));

  layer->Paint(display_list_paint_context());
  DisplayListBuilder expected_builder;
  /* (Transform)layer::Paint */ {
    expected_builder.Save();
    {
      expected_builder.Transform(layer_transform);
      /* mock_layer::Paint */ {
        expected_builder.DrawPath(child_path, DlPaint());
      }
    }
    expected_builder.Restore();
  }
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

TEST_F(TransformLayerTest, Nested) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  DlTransform initial_transform = DlTransform::MakeTranslate(-0.5f, -0.5f);
  DlFRect local_cull_rect = DlFRect::MakeXYWH(2.0f, 2.0f, 14.0f, 14.0f);
  DlFRect device_cull_rect = initial_transform.TransformRect(local_cull_rect);
  DlTransform layer1_transform = DlTransform::MakeTranslate(2.5f, 2.5f);
  DlTransform layer2_transform = DlTransform::MakeTranslate(3.5f, 3.5f);
  auto inverse_layer1_transform = layer1_transform.Inverse();
  auto inverse_layer2_transform = layer2_transform.Inverse();
  ENFORCE_TRUE(inverse_layer1_transform.has_value());
  ENFORCE_TRUE(inverse_layer2_transform.has_value());

  auto mock_layer = std::make_shared<MockLayer>(child_path, DlPaint());
  auto layer1 = std::make_shared<TransformLayer>(layer1_transform);
  auto layer2 = std::make_shared<TransformLayer>(layer2_transform);
  layer1->Add(layer2);
  layer2->Add(mock_layer);

  preroll_context()->state_stack.set_preroll_delegate(device_cull_rect,
                                                      initial_transform);
  layer1->Preroll(preroll_context());
  EXPECT_EQ(mock_layer->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer2->paint_bounds(),
            layer2_transform.TransformRect(mock_layer->paint_bounds()));
  EXPECT_EQ(layer2->child_paint_bounds(), mock_layer->paint_bounds());
  EXPECT_EQ(layer1->paint_bounds(),
            layer1_transform.TransformRect(layer2->paint_bounds()));
  EXPECT_EQ(layer1->child_paint_bounds(), layer2->paint_bounds());
  EXPECT_TRUE(mock_layer->needs_painting(paint_context()));
  EXPECT_TRUE(layer2->needs_painting(paint_context()));
  EXPECT_TRUE(layer1->needs_painting(paint_context()));
  EXPECT_EQ(mock_layer->parent_matrix(),
            DlTransform::MakeConcat(
                DlTransform::MakeConcat(initial_transform, layer1_transform),
                layer2_transform));
  EXPECT_EQ(mock_layer->parent_cull_rect(),
            inverse_layer2_transform->TransformRect(
                inverse_layer1_transform->TransformRect(local_cull_rect)));
  EXPECT_EQ(
      mock_layer->parent_mutators(),
      std::vector({Mutator(layer1_transform), Mutator(layer2_transform)}));

  layer1->Paint(display_list_paint_context());
  DisplayListBuilder expected_builder;
  /* (Transform)layer1::Paint */ {
    expected_builder.Save();
    {
      expected_builder.Transform(layer1_transform);
      /* (Transform)layer1::Paint */ {
        expected_builder.Save();
        {
          expected_builder.Transform(layer2_transform);
          /* mock_layer::Paint */ {
            expected_builder.DrawPath(child_path, DlPaint());
          }
        }
        expected_builder.Restore();
      }
    }
    expected_builder.Restore();
  }
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

TEST_F(TransformLayerTest, NestedSeparated) {
  DlPath child_path = DlPath::MakeRectLTRB(5.0f, 6.0f, 20.5f, 21.5f);
  DlTransform initial_transform = DlTransform::MakeTranslate(-0.5f, -0.5f);
  DlFRect local_cull_rect = DlFRect::MakeXYWH(2.0f, 2.0f, 14.0f, 14.0f);
  DlFRect device_cull_rect = initial_transform.TransformRect(local_cull_rect);
  DlTransform layer1_transform = DlTransform::MakeTranslate(2.5f, 2.5f);
  DlTransform layer2_transform = DlTransform::MakeTranslate(3.5f, 3.5f);
  auto inverse_layer1_transform = layer1_transform.Inverse();
  auto inverse_layer2_transform = layer2_transform.Inverse();
  ENFORCE_TRUE(inverse_layer1_transform.has_value());
  ENFORCE_TRUE(inverse_layer2_transform.has_value());
  DlPaint child_paint1(DlColor::kBlue());
  DlPaint child_paint2(DlColor::kGreen());

  auto mock_layer1 = std::make_shared<MockLayer>(child_path, child_paint1);
  auto mock_layer2 = std::make_shared<MockLayer>(child_path, child_paint2);
  auto layer1 = std::make_shared<TransformLayer>(layer1_transform);
  auto layer2 = std::make_shared<TransformLayer>(layer2_transform);
  layer1->Add(mock_layer1);
  layer1->Add(layer2);
  layer2->Add(mock_layer2);

  preroll_context()->state_stack.set_preroll_delegate(device_cull_rect,
                                                      initial_transform);
  layer1->Preroll(preroll_context());
  DlFRect layer1_child_bounds = layer2->paint_bounds();
  layer1_child_bounds.Join(mock_layer1->paint_bounds());
  DlFRect expected_layer1_bounds =
      layer1_transform.TransformRect(layer1_child_bounds);

  EXPECT_EQ(mock_layer2->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer2->paint_bounds(),
            layer2_transform.TransformRect(mock_layer2->paint_bounds()));
  EXPECT_EQ(layer2->child_paint_bounds(), mock_layer2->paint_bounds());
  EXPECT_EQ(mock_layer1->paint_bounds(), child_path.Bounds());
  EXPECT_EQ(layer1->paint_bounds(), expected_layer1_bounds);
  EXPECT_EQ(layer1->child_paint_bounds(), layer1_child_bounds);
  EXPECT_TRUE(mock_layer2->needs_painting(paint_context()));
  EXPECT_TRUE(layer2->needs_painting(paint_context()));
  EXPECT_TRUE(mock_layer1->needs_painting(paint_context()));
  EXPECT_TRUE(layer1->needs_painting(paint_context()));
  EXPECT_EQ(mock_layer1->parent_matrix(),
            DlTransform::MakeConcat(initial_transform, layer1_transform));
  EXPECT_EQ(mock_layer2->parent_matrix(),
            DlTransform::MakeConcat(
                DlTransform::MakeConcat(initial_transform, layer1_transform),
                layer2_transform));
  EXPECT_EQ(mock_layer1->parent_cull_rect(),
            inverse_layer1_transform->TransformRect(local_cull_rect));
  EXPECT_EQ(mock_layer2->parent_cull_rect(),
            inverse_layer2_transform->TransformRect(
                inverse_layer1_transform->TransformRect(local_cull_rect)));
  EXPECT_EQ(mock_layer1->parent_mutators(),
            std::vector({Mutator(layer1_transform)}));
  EXPECT_EQ(
      mock_layer2->parent_mutators(),
      std::vector({Mutator(layer1_transform), Mutator(layer2_transform)}));

  layer1->Paint(display_list_paint_context());
  DisplayListBuilder expected_builder;
  /* (Transform)layer1::Paint */ {
    expected_builder.Save();
    {
      expected_builder.Transform(layer1_transform);
      /* mock_layer::Paint */ {
        expected_builder.DrawPath(child_path, child_paint1);
      }
      /* (Transform)layer1::Paint */ {
        expected_builder.Save();
        {
          expected_builder.Transform(layer2_transform);
          /* mock_layer::Paint */ {
            expected_builder.DrawPath(child_path, child_paint2);
          }
        }
        expected_builder.Restore();
      }
    }
    expected_builder.Restore();
  }
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

TEST_F(TransformLayerTest, OpacityInheritance) {
  auto path1 = DlPath::MakeRectLTRB(10, 10, 30, 30);
  auto mock1 = MockLayer::MakeOpacityCompatible(path1);
  auto transform1 =
      std::make_shared<TransformLayer>(DlTransform::MakeScale(2, 2));
  transform1->Add(mock1);

  // TransformLayer will pass through compatibility from a compatible child
  PrerollContext* context = preroll_context();
  transform1->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags,
            LayerStateStack::kCallerCanApplyOpacity);

  auto path2 = DlPath::MakeRectLTRB(40, 40, 50, 50);
  auto mock2 = MockLayer::MakeOpacityCompatible(path2);
  transform1->Add(mock2);

  // TransformLayer will pass through compatibility from multiple
  // non-overlapping compatible children
  transform1->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags,
            LayerStateStack::kCallerCanApplyOpacity);

  auto path3 = DlPath::MakeRectLTRB(20, 20, 40, 40);
  auto mock3 = MockLayer::MakeOpacityCompatible(path3);
  transform1->Add(mock3);

  // TransformLayer will not pass through compatibility from multiple
  // overlapping children even if they are individually compatible
  transform1->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags, 0);

  auto transform2 =
      std::make_shared<TransformLayer>(DlTransform::MakeScale(2, 2));
  transform2->Add(mock1);
  transform2->Add(mock2);

  // Double check first two children are compatible and non-overlapping
  transform2->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags,
            LayerStateStack::kCallerCanApplyOpacity);

  auto path4 = DlPath::MakeRectLTRB(60, 60, 70, 70);
  auto mock4 = MockLayer::Make(path4);
  transform2->Add(mock4);

  // The third child is non-overlapping, but not compatible so the
  // TransformLayer should end up incompatible
  transform2->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags, 0);
}

TEST_F(TransformLayerTest, OpacityInheritancePainting) {
  auto path1 = DlPath::MakeRectLTRB(10, 10, 30, 30);
  auto mock1 = MockLayer::MakeOpacityCompatible(path1);
  auto path2 = DlPath::MakeRectLTRB(40, 40, 50, 50);
  auto mock2 = MockLayer::MakeOpacityCompatible(path2);
  auto transform = DlTransform::MakeScale(2, 2);
  auto transform_layer = std::make_shared<TransformLayer>(transform);
  transform_layer->Add(mock1);
  transform_layer->Add(mock2);

  // TransformLayer will pass through compatibility from multiple
  // non-overlapping compatible children
  PrerollContext* context = preroll_context();
  transform_layer->Preroll(context);
  EXPECT_EQ(context->renderable_state_flags,
            LayerStateStack::kCallerCanApplyOpacity);

  int opacity_alpha = 0x7F;
  DlFPoint offset = DlFPoint(10, 10);
  auto opacity_layer = std::make_shared<OpacityLayer>(opacity_alpha, offset);
  opacity_layer->Add(transform_layer);
  opacity_layer->Preroll(context);
  EXPECT_TRUE(opacity_layer->children_can_accept_opacity());

  DisplayListBuilder expected_builder;
  /* opacity_layer paint */ {
    expected_builder.Save();
    {
      expected_builder.Translate(offset);
      /* transform_layer paint */ {
        expected_builder.Save();
        expected_builder.Transform(transform);
        /* child layer1 paint */ {
          expected_builder.DrawPath(path1, DlPaint().setAlpha(opacity_alpha));
        }
        /* child layer2 paint */ {
          expected_builder.DrawPath(path2, DlPaint().setAlpha(opacity_alpha));
        }
        expected_builder.Restore();
      }
    }
    expected_builder.Restore();
  }

  opacity_layer->Paint(display_list_paint_context());
  EXPECT_TRUE(DisplayListsEQ_Verbose(display_list(), expected_builder.Build()));
}

using TransformLayerLayerDiffTest = DiffContextTest;

TEST_F(TransformLayerLayerDiffTest, Transform) {
  auto path1 = DlPath::MakeRect(DlFRect::MakeLTRB(0, 0, 50, 50));
  auto m1 = std::make_shared<MockLayer>(path1);

  auto transform1 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(10, 10));
  transform1->Add(m1);

  MockLayerTree t1;
  t1.root()->Add(transform1);

  auto damage = DiffLayerTree(t1, MockLayerTree());
  EXPECT_EQ(damage.frame_damage, DlIRect::MakeLTRB(10, 10, 60, 60));

  auto transform2 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(20, 20));
  transform2->Add(m1);
  transform2->AssignOldLayer(transform1.get());

  MockLayerTree t2;
  t2.root()->Add(transform2);

  damage = DiffLayerTree(t2, t1);
  EXPECT_EQ(damage.frame_damage, DlIRect::MakeLTRB(10, 10, 70, 70));

  auto transform3 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(20, 20));
  transform3->Add(m1);
  transform3->AssignOldLayer(transform2.get());

  MockLayerTree t3;
  t3.root()->Add(transform3);

  damage = DiffLayerTree(t3, t2);
  EXPECT_EQ(damage.frame_damage, DlIRect());
}

TEST_F(TransformLayerLayerDiffTest, TransformNested) {
  auto path1 = DlPath::MakeRect(DlFRect::MakeLTRB(0, 0, 50, 50));
  auto m1 = CreateContainerLayer(std::make_shared<MockLayer>(path1));
  auto m2 = CreateContainerLayer(std::make_shared<MockLayer>(path1));
  auto m3 = CreateContainerLayer(std::make_shared<MockLayer>(path1));

  auto transform1 =
      std::make_shared<TransformLayer>(DlTransform::MakeScale(2.0, 2.0));

  auto transform1_1 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(10, 10));
  transform1_1->Add(m1);
  transform1->Add(transform1_1);

  auto transform1_2 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(100, 100));
  transform1_2->Add(m2);
  transform1->Add(transform1_2);

  auto transform1_3 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(200, 200));
  transform1_3->Add(m3);
  transform1->Add(transform1_3);

  MockLayerTree l1;
  l1.root()->Add(transform1);

  auto damage = DiffLayerTree(l1, MockLayerTree());
  EXPECT_EQ(damage.frame_damage, DlIRect::MakeLTRB(20, 20, 500, 500));

  auto transform2 =
      std::make_shared<TransformLayer>(DlTransform::MakeScale(2.0, 2.0));

  auto transform2_1 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(10, 10));
  transform2_1->Add(m1);
  transform2_1->AssignOldLayer(transform1_1.get());
  transform2->Add(transform2_1);

  // Offset 1px from transform1_2 so that they're not the same
  auto transform2_2 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(100, 101));
  transform2_2->Add(m2);
  transform2_2->AssignOldLayer(transform1_2.get());
  transform2->Add(transform2_2);

  auto transform2_3 =
      std::make_shared<TransformLayer>(DlTransform::MakeTranslate(200, 200));
  transform2_3->Add(m3);
  transform2_3->AssignOldLayer(transform1_3.get());
  transform2->Add(transform2_3);

  MockLayerTree l2;
  l2.root()->Add(transform2);

  damage = DiffLayerTree(l2, l1);

  // transform2 has not transform1 assigned as old layer, so it should be
  // invalidated completely
  EXPECT_EQ(damage.frame_damage, DlIRect::MakeLTRB(20, 20, 500, 500));

  // now diff the tree properly, the only difference being transform2_2 and
  // transform_2_1
  transform2->AssignOldLayer(transform1.get());
  damage = DiffLayerTree(l2, l1);

  EXPECT_EQ(damage.frame_damage, DlIRect::MakeLTRB(200, 200, 300, 302));
}

}  // namespace testing
}  // namespace flutter
